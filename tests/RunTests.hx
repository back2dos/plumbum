package ;

class RunTests {

  static function main() {
    function assertEq<T>(found:T, expected:T) {
      if (found != expected) {
        trace('expected $expected but found $found');
        travix.Logger.exit(500);
      }
    }
    var counter = 0;
    var x = new Example2({
      foo: '4321',
      bar: function (s) {
        var a = s.split('');
        a.reverse();
        return a.join('');
      },
      blub: 'foo${counter += 1}',
    });

    assertEq(x.result, '1234');
    assertEq(counter, 0);
    assertEq(x.result2, '1234foo1');
    assertEq(x.result3, 'foo11234');
    assertEq(counter, 1);

    travix.Logger.exit(0);
  }
  
}

class Example1 implements plumbum.Scope {

}

class Example2 implements plumbum.Scope {
  var dependencies:{
    var foo:String;
    function bar(x:String):String;
    var blub:String;
  }
  // public var result4:String = result; //<-- this line should not compile
  public var result:String = bar(dependencies.foo);
  public var result2:String = result + blub;
  public var result3:String = blub + result;
}