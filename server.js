// server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io     = new Server(server);

// public フォルダ内の index.html を配信
app.use(express.static(__dirname));

// ルーム管理用ストレージ
const rooms = {};

function checkWin(board) {
  const lines = [
    [0,1,2],[3,4,5],[6,7,8],
    [0,3,6],[1,4,7],[2,5,8],
    [0,4,8],[2,4,6]
  ];
  for (const [a,b,c] of lines) {
    if (board[a] && board[a] === board[b] && board[a] === board[c]) {
      return board[a];
    }
  }
  if (board.every(cell => cell)) return 'draw';
  return null;
}

io.on('connection', socket => {
  // “default” ルームに強制参加
  const roomCode = 'default';
  socket.join(roomCode);
  if (!rooms[roomCode]) {
    rooms[roomCode] = { board: Array(9).fill(null), turn: 'X', gameOver: false };
  }
  const room = rooms[roomCode];
  
   // 参加プレイヤー数をカウントして symbol を決定
  room.players = room.players || [];
  const symbol = room.players.length === 0 ? 'X' : 'O';
  room.players.push(socket.id);

  // 初回接続時にクライアントへ現在の盤面と手番・自分の記号を送信
  socket.emit('joined', {
    symbol,           // ← ここが null → 'X' or 'O' になります
    board: room.board,
    turn: room.turn
  });
  
  socket.on('makeMove', idx => {
    if (room.gameOver || room.board[idx]) return;
    room.board[idx] = room.turn;
    const result = checkWin(room.board);
    if (result) {
      room.gameOver = true;
      io.to(roomCode).emit('gameOver', { result, board: room.board });
    } else {
      room.turn = room.turn === 'X' ? 'O' : 'X';
      io.to(roomCode).emit('update', { board: room.board, turn: room.turn });
    }
  });

  socket.on('disconnect', () => {
    delete rooms[roomCode];
    io.to(roomCode).emit('opponentLeft');
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
