// Scrolling strip of use cases. The list is doubled so the loop has no visible seam.
const uses = ["Goa trip", "Flat rent", "Office lunches", "Road trips", "Groceries", "Concert tickets", "Birthday gifts", "Weekend getaways"];
const star = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#ef9f27" stroke-width="3" stroke-linecap="round"><path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9"/></svg>';
document.getElementById("marquee").innerHTML = [...uses, ...uses].map((use) => `<li>${use}${star}</li>`).join("");

// "Try a split" calculator.
const amountInput = document.getElementById("amount");
const peopleOutput = document.getElementById("people");
const eachOutput = document.getElementById("each");
const owedOutput = document.getElementById("owed");
const MIN_PEOPLE = 2;
const MAX_PEOPLE = 30;
let people = 4;

const money = (n) => "₹" + n.toLocaleString("en-IN", { maximumFractionDigits: 2 });

function update() {
  const amount = Math.max(0, parseFloat(amountInput.value) || 0);
  const each = amount / people;
  const friends = people - 1;
  peopleOutput.textContent = people;
  eachOutput.textContent = `${money(each)} each`;
  owedOutput.textContent = friends === 1
    ? `1 friend owes you ${money(each)}`
    : `${friends} friends owe you ${money(each * friends)}`;
}

amountInput.addEventListener("input", update);
document.getElementById("less").addEventListener("click", () => { people = Math.max(MIN_PEOPLE, people - 1); update(); });
document.getElementById("more").addEventListener("click", () => { people = Math.min(MAX_PEOPLE, people + 1); update(); });
document.getElementById("calc").addEventListener("submit", (event) => event.preventDefault());
update();
