import Bench "mo:bench";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    // benchmark code...
    bench.name("My benchmark name");
    bench.description("My description");

    bench.rows(["bench1"]);
    bench.cols(["val0"]);


    bench.runner(func(row, col) {
      // benchmark code...
    });

    bench;
  };
};