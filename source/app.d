import std.conv : to;

enum Mark : int {
	BLACK = 1,
	WHITE = -1,
	EMPTY = 0,
	INVALID = 999,
}

struct NextAction {
private:
	int type;
	Position p;

	@disable this();
	this(int type) pure nothrow @safe {
		this.type = type;
	}
public:
	static NextAction PutAt(Position p) pure nothrow @safe {
		auto a = NextAction(0);
		a.p = p;
		return a;
	}
	static NextAction Pass() pure nothrow @safe {
		auto a = NextAction(1);
		return a;
	}
	bool IsPass() pure const nothrow @safe {
		return this.type == 1;
	}
	Position GetPutAt() pure const @safe{
		if (this.type != 0) {
			throw new Exception("This action is not put, so couldn't get position where to put");
		}
		return this.p;
	}
}


struct Position {
public:
	int x;
	int y;
}

interface ReversiPlayer {
public:
	void SetMark(Mark) pure nothrow @safe;
	Mark GetMark() pure nothrow const @safe;
	NextAction GetNextAction(const ReversiBoard) pure const;
}


class ReversiMinicandidatesPlayer : ReversiPlayer {
private:
	Mark mark;
public:
	this(Mark mark) pure nothrow @safe {
		this.mark = mark;
	}
	void SetMark(Mark) pure nothrow @safe {
		this.mark = mark;
	}
	Mark GetMark() pure nothrow const @safe {
		return this.mark;
	}

	NextAction GetNextAction(const ReversiBoard board) pure const {
		import std.random : choice;
		auto puttables = board.ListupPuttables(mark);
		if (puttables.length == 0) {
			return NextAction.Pass();
		}
		ulong minv = board.size * board.size;
		Position[] candidates = [];
		foreach (at; puttables) {
			auto newBoard = board.PutAt(at.x, at.y, mark);
			auto enemyPuttables = newBoard.ListupPuttables(-mark);
			if (enemyPuttables.length <= minv) {
				minv = enemyPuttables.length;
				candidates ~= at;
			}
		}
		if (candidates.length == 0) {
			throw new Exception("WHY JAPANESE PEOPLE!!!!");
		}
		return NextAction.PutAt(choice(candidates));
	}
}

class ReversiRandomPlayer : ReversiPlayer {
private:
	Mark mark;
public:
	this(Mark mark) pure nothrow @safe {
		this.mark = mark;
	}
	void SetMark(Mark mark) pure nothrow @safe {
		this.mark = mark;
	}
	Mark GetMark() pure const nothrow @safe {
		return this.mark;
	}
	NextAction GetNextAction(const ReversiBoard board) pure const {
		import std.random : choice;
		auto puttables = board.ListupPuttables(mark);
		if (puttables.length == 0) {
			return NextAction.Pass();
		}
		return NextAction.PutAt(choice(puttables));
	}

}

class ReversiManager {
private:
	ReversiBoard board;
	ReversiPlayer[] players;
	int turn;
	int turnPlayerIndex;

	ReversiPlayer GetTurnPlayer() pure @safe {
		return players[turnPlayerIndex];
	}
public:
	this(ReversiPlayer player1, ReversiPlayer player2) pure @safe {
		this.board = new ReversiBoard();
		if (player1 is null) {
			throw new Exception("Player1 is null");
		}
		if (player2 is null) {
			throw new Exception("Player2 is null");
		}
		this.players = [player1, player2];
		this.turn = 0;
		this.turnPlayerIndex = 0;
	}
	void GoNextTurn() pure @safe {
		this.turn ++;
		this.turnPlayerIndex = (this.turnPlayerIndex+1)%2;
	}
	void Next() pure {
		auto nextAction = GetTurnPlayer().GetNextAction(this.board);
		if (! nextAction.IsPass()) {
			auto putAt = nextAction.GetPutAt();
			this.board = board.PutAt(putAt.x, putAt.y, GetTurnPlayer().GetMark());
		}
		if (! this.board.IsGameEnd()) {
			GoNextTurn();
		}
	}
	ReversiBoard GetBoard() pure nothrow @safe {
		return this.board;
	}
}

class ReversiBoard {
private:
	Mark[][] board;
	const int size = 8;
public:
	this() pure nothrow @safe {
		this.board = new Mark[][](size,size);
		for (int x = 0; x < size; x++) {
			for (int y = 0; y < size; y++) {
				this.board[x][y] = Mark.EMPTY;
			}
		}
		this.board[3][3] = Mark.BLACK;
		this.board[3][4] = Mark.WHITE;
		this.board[4][3] = Mark.WHITE;
		this.board[4][4] = Mark.BLACK;
	}
	this(const(Mark[][]) board) pure nothrow @safe {
		this.board = board.to!(Mark[][]); // copy 
	}

	/// return specific position status of board
	Mark At(int x, int y) pure nothrow const @safe {
		if (0 <= x && x < this.size && 0 <= y && y < this.size) {
			return board[x][y];
		}
		return Mark.INVALID;
	}

	/// return string expression of board status
	string String() pure nothrow const @safe {
		import std.range : repeat;
		import std.array : join;

		char[] buf = [];
		buf ~= "v".repeat(10).join("") ~ "\n";
		for (int y = 0; y < this.size; y++) {
			buf ~= "|";
			for (int x = 0; x < this.size; x++) {
				if (this.At(x,y) == Mark.BLACK) {
					buf ~= "*";
				}
				else if (this.At(x,y) == Mark.WHITE) {
					buf ~= "o";
				}
				else {
					buf ~= "-";
				}
			}
			buf ~= "|\n";
		}
		buf ~= "^".repeat(10).join("") ~ "\n";

		return buf.to!string;
	}

	Position[] ReversesWhenPut(int x, int y, Mark mark) pure const @safe {
		with (Mark) {
			if (this.At(x,y) != EMPTY) {
				return [];
			}
			Position[] poses = [];

			auto dx = [-1, 0, 1, -1, 1, -1, 0, 1];
			auto dy = [-1, -1, -1, 0, 0, 1, 1, 1];
			
			// search 8-neighbor
			for (int i = 0; i < dx.length; i++) {
				if (this.At(x+dx[i], y+dy[i]) == -mark) {
					Position[] candidates = [];
					bool flag = false;
					int j = 1;
					// go next next next ... until a == mark
					while (true) {
						auto a = this.At(x+dx[i]*j, y+dy[i]*j);
						if (a == -mark) {
							candidates ~= Position(x+dx[i]*j, y+dy[i]*j);
						}
						else if (a == mark) {
							flag = true;
							break;
						}
						else {
							break;
						}
						j++;
					}
					// add revesed positions
					if (flag && candidates.length > 0) {
						poses ~= candidates;
					}
				}
			}
			return poses;
		}
	}

	ReversiBoard PutAt(int x, int y, Mark mark) pure const @safe {
		import std.format : format;
		auto revs = ReversesWhenPut(x, y, mark);
		if (revs.length == 0) {
			throw new Exception("Position(%d, %d) is not puttable".format(x,y));
		}
		ReversiBoard copy = new ReversiBoard(this.board);
		copy.board[x][y] = mark;
		foreach (p; revs) {
			copy.board[p.x][p.y] = mark;
		}
		return copy;
	}

	Position[] ListupPuttables(Mark mark) pure const @safe {
		Position[] puttables = [];
		for (int x = 0; x < this.size; x++) {
			for (int y = 0; y < this.size; y++) {
				if (IsPuttableAt(x,y,mark)) {
					puttables ~= Position(x,y);
				}
			}
		}
		return puttables;
	}
	
	bool IsPuttableAt(int x, int y, Mark mark) pure const @safe {
		with (Mark) {
			if (this.At(x,y) != EMPTY) {
				return false;
			}

			auto dx = [-1, 0, 1, -1, 1, -1, 0, 1];
			auto dy = [-1, -1, -1, 0, 0, 1, 1, 1];
			
			// search 8-neighbor
			for (int i = 0; i < dx.length; i++) {
				if (this.At(x+dx[i], y+dy[i]) == -mark) {
					bool flag = true;
					int j = 2;
					// go next next next ... until a == mark
					while (true) {
						auto a = this.At(x+dx[i]*j, y+dy[i]*j);
						if (a == -mark) {
						}
						else if (a == mark) {
							break;
						}
						else {
							flag = false;
							break;
						}
						j++;
					}
					if (flag) {
						return true;
					}
				}
			}
			return false;
		}
	}

	uint Count(Mark mark) pure nothrow const @safe {
		uint cnt = 0;
		for (int x = 0; x < this.size; x++) {
			for (int y = 0; y < this.size; y++) {
				if (this.At(x,y) == mark) {
					cnt++;
				}
			}
		}
		return cnt;
	}

	bool IsGameEnd() pure const @safe{
		if (ListupPuttables(Mark.BLACK).length == 0 && ListupPuttables(Mark.WHITE).length == 0)  {
			return true;
		}
		for (int x = 0; x < this.size; x++) {
			for (int y = 0; y < this.size; y++) {
				if (this.At(x,y) == Mark.EMPTY) {
					return false;
				}
			}
		}
		return true;
	}
}

void main()
{
	import std.stdio : write, writeln;
	import core.thread : Thread;
	import core.time : dur;

	ReversiPlayer player1 = new ReversiMinicandidatesPlayer(Mark.BLACK);
	ReversiPlayer player2 = new ReversiMinicandidatesPlayer(Mark.WHITE);

	auto game = new ReversiManager(player1, player2);
	while (! game.GetBoard().IsGameEnd()) {
		write("\033[2J");
		write(game.GetBoard().String());
		game.Next();

		Thread.sleep(dur!("msecs")(100));
	}
	write("\033[2J");
	write(game.GetBoard().String());

	writeln("BLACK: ", game.GetBoard().Count(Mark.BLACK));
	writeln("WHITE: ", game.GetBoard().Count(Mark.WHITE));

}
