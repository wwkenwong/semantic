final class DoubtTests: XCTestCase {
	func testEqualSyntaxResultsInRecursivelyCopyingDiff() {
		if let s = sexpr("\t(\n( a) \n)\t")?.value, t = sexpr("((a))")?.value {
			XCTAssertEqual(Diff(s, t), Diff.Copy(.Apply(.Copy(.Apply(.Copy(.Variable("a")), [])), [])))
		}
	}
}

let atom = Syntax<Fix>.Variable <^> ^("abcdefghijklmnopqrstuvwxyz".characters.map { String($0) })
let ws = ^(" \t\n".characters.map { String($0) })

let sexpr: String -> State<Fix>? = fix { sexpr in
	let list = Syntax<Fix>.Apply <^> (ws* *> ^"(" *> ws* *> sexpr <*> sexpr* <* ^")")
	return Fix.init <^> (atom <|> list) <* ws*
}


func fix<T, U>(f: (T -> U) -> T -> U) -> T -> U {
	return { f(fix(f))($0) }
}


import Doubt
import XCTest