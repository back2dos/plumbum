package ;

class RunTests {

  static function main() {
    var x = new Example2({
      foo: '4321',
      bar: function (s) {
        var a = s.split('');
        a.reverse();
        return a.join('');
      }
    });
    travix.Logger.exit(
      if (x.result2 == '12341234') 0 else 500
    );
  }
  
}

class Example1 implements plumbum.Scope {

}

class Example2 implements plumbum.Scope {
  var dependencies:{
    var foo:String;
    function bar(x:String):String;
  }
  // public var result3:String = result; <-- this line should not compile
  public var result:String = bar(foo);
  public var result2:String = result + result;
}