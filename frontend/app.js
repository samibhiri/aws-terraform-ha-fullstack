// API_URL is defined in config.js, generated at boot with the ALB DNS name
const list = document.getElementById("messages");
const form = document.getElementById("form");
const input = document.getElementById("content");

async function loadMessages() {
  const res = await fetch(`${API_URL}/api/messages`);
  const messages = await res.json();
  list.innerHTML = "";
  for (const m of messages) {
    const li = document.createElement("li");
    li.textContent = m.content;
    list.appendChild(li);
  }
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  await fetch(`${API_URL}/api/messages`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content: input.value }),
  });
  input.value = "";
  loadMessages();
});

loadMessages();