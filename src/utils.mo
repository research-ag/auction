import Iter "mo:base/Iter";
import List "mo:base/List";

module {

  // goes through list, finds one needed element and removes it if found. Returns updated list and flag is item was found and deleted
  public func listFindOneAndDelete<T>(list : List.List<T>, f : T -> Bool) : (List.List<T>, Bool) {
    switch list {
      case null { (null, false) };
      case (?(h, t)) {
        if (f(h)) {
          (t, true);
        } else {
          listFindOneAndDelete<T>(t, f) |> (?(h, _.0), _.1);
        };
      };
    };
  };

  // goes through list, finds first element for which f will return true, and inserts provided element BEFORE it
  public func insertWithPriority<T>(list : List.List<T>, item : T, f : T -> Bool) : List.List<T> {
    switch list {
      case null { ?(item, null) };
      case (?(h, t)) {
        if (f(h)) {
          ?(item, list);
        } else {
          insertWithPriority<T>(t, item, f) |> ?(h, _);
        };
      };
    };
  };

  /** concat two iterables into one */
  public func iterConcat<T>(a : Iter.Iter<T>, b : Iter.Iter<T>) : Iter.Iter<T> {
    var aEnded : Bool = false;
    object {
      public func next() : ?T {
        if (aEnded) {
          return b.next();
        };
        let nextA = a.next();
        switch (nextA) {
          case (?val) ?val;
          case (null) {
            aEnded := true;
            b.next();
          };
        };
      };
    };
  };

};
