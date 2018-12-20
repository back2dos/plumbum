package ;

class RunTests {

  static function main() {
    function assertEq<T>(found:T, expected:T, ?pos:haxe.PosInfos) {
      if (found != expected) {
        haxe.Log.trace('expected $expected but found $found', pos);
        travix.Logger.exit(500);
      }
    }
    var counter = 0;
    var x = new Example2({
      foo: '4321',
      blub: 'foo${counter += 1}',
    });

    assertEq(x.result, '1234');
    assertEq(counter, 0);
    assertEq(x.result2, '1234foo1');
    assertEq(x.result3, 'foo11234');
    assertEq(counter, 1);

    assertEq(x.computed, 0);
    assertEq(x.computed, 1);

    travix.Logger.println('assertions hold');
    travix.Logger.exit(0);
  }
  
}

class Example1 implements plumbum.Scope {

}

@:tink class Example2 implements plumbum.Scope {
  var dependencies:{
    var foo:String;
    @:lazy function bar(s:String):String {
      var a = s.split('');
      a.reverse();
      return a.join('');
    };
    @:lazy var blub:String;
  }
  // public var result4:String = result; //<-- this line should not compile
  public var result:String = bar(dependencies.foo);
  public var result2:String = result + blub;
  public var result3:String = blub + result;
  @:computed var computed:Int = counter++;
  static var counter:Int = 0;
}