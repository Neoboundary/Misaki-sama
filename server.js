// server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.static(__dirname)); // 必要に応じて public/ に分離してね

function freshRoom() {
  return {
    players: [],             // [{id, role:'drawer'|'guesser'}] 観戦者は配列に入れない
    watchers: new Set(),     // 観戦者 socket.id
    answer: null,            // 現在のお題（サーバのみ）
    roundTimer: null,
    seconds: 60,             // ラウンド持ち時間
    running: false,
  };
}

const rooms = {}; // roomCode -> roomState

const WORDS = [
  'ねこ','いぬ','バナナ','自転車','山','傘','飛行機','時計','家','星','電車','はさみ','魚','コップ','本'
];

function normalize(s) {
  return s.replace(/\s+/g, '')
          .replace(/[Ａ-Ｚａ-ｚ０-９]/g, ch => String.fromCharCode(ch.charCodeAt(0) - 0xFEE0))
          .toLowerCase();
}

function startRound(roomCode) {
  const room = rooms[roomCode];
  if (!room || room.players.length < 2) return;

  clearTimeout(room.roundTimer);
  room.running = true;
  room.answer = WORDS[Math.floor(Math.random() * WORDS.length)];
  const seconds = room.seconds;

  // 役割は交代
  room.players.reverse();
  room.players[0].role = 'drawer';
  room.players[1].role = 'guesser';

  io.to(roomCode).emit('roundStarted', {
    role: null,   // 個別に送るので全体ブロードキャストは null で
    hint: null,
    seconds,
  });
  // 個別に役割とヒントを送る
  const drawer = room.players[0];
  const guesser = room.players[1];
  io.to(drawer.id).emit('roundStarted', { role: 'drawer', hint: room.answer, seconds });
  io.to(guesser.id).emit('roundStarted', { role: 'guesser', hint: null, seconds });

  // 観戦者には役割なし
  for (const wid of room.watchers) {
    io.to(wid).emit('roundStarted', { role: null, hint: null, seconds });
  }

  // サーバ側カウントダウン（信頼できる残秒を時々送る）
  let remain = seconds;
  const tick = () => {
    remain--;
    if (remain >= 0) io.to(roomCode).emit('tick', remain);
    if (remain <= 0) {
      endRound(roomCode, 'timeout');
    } else {
      room.roundTimer = setTimeout(tick, 1000);
    }
  };
  room.roundTimer = setTimeout(tick, 1000);
}

function endRound(roomCode, reason) {
  const room = rooms[roomCode];
  if (!room) return;
  clearTimeout(room.roundTimer);
  room.running = false;
  const answer = room.answer;
  room.answer = null;

  // 役割は次ラウンドで反転するため、ここでは何もしないが、クライアント表示用に次の自分の役を通知
  const nextDrawer = room.players[1]?.id;
  const nextGuesser = room.players[0]?.id;

  if (reason === 'timeout') {
    io.to(roomCode).emit('result', { type: 'timeout', answer, nextRole: null });
  } else if (reason === 'correct') {
    io.to(roomCode).emit('result', { type: 'correct', answer, nextRole: null });
  }
}

io.on('connection', (socket) => {
  let roomCode = null;

  socket.on('joinRoom', (code) => {
    roomCode = String(code || 'default');
    if (!rooms[roomCode]) rooms[roomCode] = freshRoom();
    const room = rooms[roomCode];

    // 二人までプレイヤー、それ以外は観戦
    if (room.players.length < 2) {
      const role = room.players.length === 0 ? 'drawer' : 'guesser';
      room.players.push({ id: socket.id, role });
      socket.join(roomCode);
      socket.emit('joined', { role, message: 'プレイヤーとして参加しました', seconds: room.seconds });
      // すでにラウンド中なら役割を同期
      socket.emit('roles', { role });
    } else {
      room.watchers.add(socket.id);
      socket.join(roomCode);
      socket.emit('joined', { role: null, message: '満員のため観戦で参加しました', seconds: room.seconds });
    }
  });

  socket.on('startRound', () => {
    const room = rooms[roomCode];
    if (!room) return;
    if (room.running) return;
    if (room.players.length < 2) return;
    startRound(roomCode);
  });

  socket.on('stroke', (seg) => {
    const room = rooms[roomCode];
    if (!room || !room.running) return;
    const me = room.players.find(p => p.id === socket.id);
    if (!me || me.role !== 'drawer') return;
    // 軽量バリデーション
    if (!seg || !seg.from || !seg.to) return;
    io.to(roomCode).emit('stroke', seg);
  });

  socket.on('clear', () => {
    const room = rooms[roomCode];
    if (!room || !room.running) return;
    const me = room.players.find(p => p.id === socket.id);
    if (!me || me.role !== 'drawer') return;
    io.to(roomCode).emit('clear');
  });

  socket.on('guess', (text) => {
    const room = rooms[roomCode];
    if (!room || !room.running) return;
    const me = room.players.find(p => p.id === socket.id);
    if (!me || me.role !== 'guesser') return;
    const guess = normalize(String(text || ''));
    const ans = normalize(room.answer || '');
    io.to(roomCode).emit('chat', `解答: ${text}`);
    if (guess && ans && guess === ans) {
      endRound(roomCode, 'correct');
    }
  });

  socket.on('disconnect', () => {
    const room = rooms[roomCode];
    if (!room) return;
    // プレイヤーから外す／観戦から外す
    const before = room.players.length;
    room.players = room.players.filter(p => p.id !== socket.id);
    room.watchers.delete(socket.id);

    socket.to(roomCode).emit('opponentLeft');

    // ラウンド中なら停止
    if (room.running) endRound(roomCode, 'timeout');

    // 誰もいなくなったら掃除
    const hasMembers = room.players.length > 0 || room.watchers.size > 0 || (io.sockets.adapter.rooms.get(roomCode)?.size || 0) > 0;
    if (!hasMembers) delete rooms[roomCode];
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
