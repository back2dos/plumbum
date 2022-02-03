package plumbum.helpers;

import tink.macro.BuildCache;
using tink.MacroApi;

class Dependencies {
  static function build() {
    return BuildCache.getType('plumbum.helpers.Dependencies', null, null, ctx -> {
      var name = ctx.name;

      var ret = macro class $name {}

      ret.meta.push({ name: ':structInit', pos: (macro null).pos });
      switch ctx.type {
        case TAnonymous(a):
          for (f in a.get().fields) {

            function add(optional, f)
              if (optional) ret.fields.push(f);
              else ret.fields.unshift(f);

            add(f.meta.has(':optional'), {
              access: [APublic],
              name: f.name,
              pos: f.pos,
              meta: f.meta.get(),
              kind: FProp('default', 'null', f.type.toComplex()),
            });
          }
        default:
          ctx.pos.error('Type parameter should be structure');
      }

      ret;
    });
  }
}