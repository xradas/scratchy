const choices = [...document.querySelectorAll('.choice')];
const packets = [...document.querySelectorAll('.packet')];
const players = [...document.querySelectorAll('audio')];

function showPacket(slug) {
  const packet = packets.find(item => item.id === slug);
  if (!packet) return;
  players.forEach(player => player.pause());
  choices.forEach(choice => choice.setAttribute('aria-pressed', String(choice.dataset.packet === slug)));
  packets.forEach(item => { item.hidden = item.id !== slug; });
  document.documentElement.style.setProperty('--accent', packet.dataset.accent);
  history.replaceState(null, '', '#' + slug);
}

choices.forEach(choice => choice.addEventListener('click', () => showPacket(choice.dataset.packet)));
players.forEach(player => {
  player.volume = 0.55;
  player.addEventListener('play', () => players.forEach(other => { if (other !== player) other.pause(); }));
});
showPacket(location.hash.slice(1) || choices[0].dataset.packet);
window.addEventListener('hashchange', () => showPacket(location.hash.slice(1)));
