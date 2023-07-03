import base, mono/[core, http], ext/persistence, std/os

# Model -------------------------------------------------------------------------------------------
type
  Square = enum
    Empty, X, O
  Board = array[3, array[3, Square]]
  Game = ref object
    board: Board

proc save(game: Game) =
  game.write_to "./tmp/tictactoe.json"

var game* {.threadvar.}: Game

# UI ----------------------------------------------------------------------------------------------
type SquareView = ref object of Component
  x, y: int

proc render(self: SquareView): El =
  proc click =
    if game.board[self.x][self.y] == Square.Empty:
      # Here you need to implement your game's logic to decide who's turn it is
      game.board[self.x][self.y] = Square.X
      game.save

  let text = case game.board[self.x][self.y]
    of Square.Empty: ""
    of Square.X: "X"
    of Square.O: "O"

  el"square":
    el("button", (text: text), it.on_click(click))

type BoardView = ref object of Component

proc render(self: BoardView): El =
  el"board":
    for x, row in game.board:
      for y, square in row:
        self.el(SquareView, (x: x, y: y))

# Deployment --------------------------------------------------------------------------------------
when is_main_module:
  game = Game.read_from("./tmp/tictactoe.json").get(() => Game(board: [[Square.Empty, Square.Empty, Square.Empty],
                                                                       [Square.Empty, Square.Empty, Square.Empty],
                                                                       [Square.Empty, Square.Empty, Square.Empty]]))

  let asset_path = current_source_path().parent_dir.absolute_path
  run_http_server((() => BoardView()), asset_paths = @[asset_path], styles = @["/assets/tictactoe.css"])
