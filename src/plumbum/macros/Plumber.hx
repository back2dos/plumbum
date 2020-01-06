package plumbum.macros;

import haxe.macro.Context.*;
import haxe.macro.Expr;

using tink.MacroApi;

class Plumber {

  static var NO_COMPLETION = [{ name: ':noCompletion', params: [], pos: (macro null).pos }];

  var dependencies = [];
  var setup = [];
  var ctorPos = currentPos();

  var postconstruct = null;
  var declarations = [];
  var fields = [];
  var vars:Array<Var> = [];
  var cls = getLocalClass().get();

  var strict:Bool;

  static var INVALID_ACCESS = ~/cannot access (.*) in static function/i;

  function new() {
    strict = !cls.meta.has(':lenient');
    triage();
    processDependencies();
    processDeclarations();
    if (strict) {
      var check = (function () {
        switch EVars(vars).at(cls.pos).typeof() {
          case Failure(e):
            if (INVALID_ACCESS.match(e.message)) e.pos.error('Field ${INVALID_ACCESS.matched(1)} accessed out of order');
            else e.throwSelf();
          default:
        }
        return macro null;
      }).bounce();
      fields = fields.concat((macro class {
        static function __plumbub__check()
          ${check}
      }).fields);
    }

    makeConstructor();
  }

  function triage()
    for (f in (getBuildFields():Array<Member>))
      if (f.isStatic) fields.push(f);
      else switch f.name {

        case 'new':

          switch f.kind {
            case FFun({ args: [], expr: body }):
              ctorPos = f.pos;
              postconstruct = body;
            case FFun(_): f.pos.error('no arguments allowed in constructor');
            default: throw 'assert';
          }

        case 'dependencies':

          switch f.kind {
            case FVar(TAnonymous(fields), null): dependencies = fields;
            case FVar(null, _): f.pos.error('type required for dependencies');
            case FVar(_.toString() => found, null): f.pos.error('dependencies must be a struct, but got $found');
            case FVar(_, e): e.reject('expression not allowed here');
            default: f.pos.error('dependencies must be plain variable');
          }

          fields.push({
            pos: f.pos,
            name: f.name,
            kind: FProp('default', 'never', TAnonymous(dependencies), null),
          });

          set('dependencies', macro dependencies);

        case name:
          switch f.kind {
            case FProp(_, _, null, _): f.pos.error('type required for properties');
            case FProp('get', 'set' | 'never', t, e):

              switch f.extractMeta(':isVar') {
                case Success(tag): tag.pos.error('cannot use @:isVar here');
                default:
              }

              if (e != null)
                e.reject('expression not allowed here');

              fields.push(f);

              vars.push({
                name: name,
                expr: macro null,
                type: t,
              });


            case FProp(_, _, _, _): f.pos.error('properties not supported yet');
            case FFun(_):

              fields.push(f);

              vars.push({
                name: name,
                expr: macro null,
                type: f.pos.makeBlankType(),
              });

            #if tink_lang
            case FVar(_, _) if (f.metaNamed(':computed').length > 0):
              fields.push(f);
            #end
            case FVar(_, null): f.pos.error('initialization required');
            case FVar(t, e):
              var f:Field = f;

              declarations.push({
                name: name,
                pos: f.pos,
                type: t,
                expr: e,
                meta: f.meta,
                isPublic: switch f.access {
                  case [APublic]: true;
                  case [APrivate] | []: false;
                  default: f.pos.error('only `public` and `private` are supported as access modifiers');
                }
              });
          }
      }

  function set(name:String, expr:Expr)
    setup.push(
      (function () {
        var target = storeTypedExpr(typeExpr(macro @:pos(expr.pos) this.$name));
        return macro @:pos(expr.pos) $target = $expr;
      }).bounce()
    );

  function processDependencies() {

    vars.push({
      name: 'dependencies',
      type: TAnonymous(dependencies),
      expr: macro null,
    });

    for (d in dependencies) {

      var name = d.name;

      var lazy = false;

      switch d.meta {
        case null | []:
        case [{ name: ':lazy' }]:
          lazy = true;
        case v: v[0].pos.error('no meta data except `@:lazy` allowed on dependencies');
      }

      function add(type, dFault) {

        vars.push({
          type: type,
          expr: macro cast null,
          name: name
        });


        fields.push({
          name: name,
          pos: d.pos,
          kind: FProp('get', 'never', type),
        });

        var body = macro @:pos(d.pos) dependencies.$name;

        var dependencyType =
          if (lazy) {
            var t = macro : plumbum.macros.Lazy<$type>;
            d.kind = FProp('default', 'never', t);
            body = macro @:pos(d.pos) $body.get();
            t;
          }
          else type;

        if (dFault != null) {
          d.meta.push({ name: ':optional', params: [], pos: d.pos });
          var writable = TAnonymous([{ name: name, pos: dFault.pos, kind: FVar(dependencyType)} ]);
          setup.push(@:pos(dFault.pos) macro if (dependencies.$name == null) (cast dependencies:$writable).$name = $dFault);
        }

        fields.push({
          name: 'get_$name',
          pos: d.pos,
          access: [AInline],
          kind: FFun({
            args: [],
            ret: type,
            expr: macro @:pos(body.pos) return $body,
          }),
        });
      }

      switch d.kind {

        case FVar(null, _): d.pos.error('type required');
        case FProp(_, _, _, _): d.pos.error('property not allowed here');

        case FVar(t, e):

          d.kind = FProp('default', 'never', t, null);
          add(t, e);

        case FFun(f):

          function check(expected, type)
            return
              if (type == null) d.pos.error('$expected expected');
              else type;

          var dFault =
            switch f.expr {
              case null: null;
              case e:
                f.expr = null;
                EFunction(null, {
                  args: f.args,
                  params: f.params,
                  ret: f.ret,
                  expr: e
                }).at(e.pos);
            }

          add(
            TFunction(
              [for (arg in f.args) {
                var t = check('type for argument ${arg.name}', arg.type);
                if (arg.opt) TOptional(t);
                else t;
              }],
              check('return type', f.ret)
            ),
            dFault
          );
      }
    }
  }

  function processDeclarations()
    for (part in declarations) {

      var name = part.name,
          type = part.type,
          expr = part.expr,
          pos  = part.pos;

      vars.push({ name: name, type: type, expr: expr });

      fields.push({
        name: name,
        pos: pos,
        meta: part.meta,
        kind: FProp('get', 'never', type, null),
        access: [if (part.isPublic) APublic else APrivate],
      });

      var lazyName = '_lazy_${part.name}',
          lazyType = macro : tink.core.Lazy<$type>;

      fields.push({
        name: lazyName,
        kind: FProp('default', 'never', lazyType, null),
        pos: pos,
        access: [APrivate],
        meta: NO_COMPLETION
      });

      fields.push({
        name: 'get_$name',
        kind: FFun({
          args: [],
          ret: type,
          expr: macro @:pos(pos) return $i{lazyName}.get(),
        }),
        access: [APrivate, AInline],
        pos: pos,
        meta: NO_COMPLETION
      });

      set(lazyName, macro @:pos(pos) (function () return ($expr : $type):$lazyType));

    }

  function makeConstructor() {
    if (postconstruct != null)
      setup.push(postconstruct);

    fields.push({
      pos: ctorPos,
      name: 'new',
      access: [APublic],
      kind: FFun({
        args: [{ name: 'dependencies', type: TAnonymous(dependencies) }],
        ret: macro : Void,
        expr: setup.toBlock(ctorPos),
      }),
    });
  }

  static function buildScope()
    return new Plumber().fields;

}