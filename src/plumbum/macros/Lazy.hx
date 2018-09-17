package plumbum.macros;

#if macro
import haxe.macro.*;
import haxe.macro.Expr;
using tink.MacroApi;
#end

@:forward
abstract Lazy<T>(tink.core.Lazy<T>) {
  public inline function new(l) this = l;
  @:from macro static public function ofAny(e:Expr) {
    var et = Context.getExpectedType().toComplex();
    var vt = (macro (null:$et).get()).typeof().sure().toComplex();
    var body = 
      Context.storeTypedExpr(Context.typeExpr(
        ECheckType(e, vt).at(e.pos)
      ));
    return macro @:pos(e.pos) new plumbum.macros.Lazy(function () return $body);
  }
    
}