window.onload = getActiveBorrows;

function getActiveBorrows() {
  fetch("/get_emprestimos_ativos")
    .then((response) => response.json())
    .then((data) => {
      let html = "";
      data.forEach((item) => {
        html += `<tr>
      <td>${item.usuario_nome}</td>
      <td>${item.item_nome}</td>
      <td>${item.item_qntd}</td>
      <td>${item.data_emprestimo}</td>
      <td>${item.data_prevista_devolucao}</td>
      <td><button id="devolver_button" onclick="returnItem(${item.emprestimo_id})">Devolver</button></td>
      </tr>`;
      });
      if (html === "") {
        document.getElementById(
          "ActiveEmprestimos"
        ).innerHTML = `<tr><td colspan="6">Nenhum empréstimo ativo</td></tr>`;
      } else {
        document.getElementById("ActiveEmprestimos").innerHTML = html;
      }
    })
    .catch((error) =>
      console.error("Erro ao carregar emprestimos ativos:", error)
    );
}
function Cobrar(
  emprestimo_id,
  usuario_nome,
  item_nome,
  item_qntd,
  data_emprestimo,
  dias_atraso
) {
  fetch("/get_telefone_usuario?emprestimo_id=" + emprestimo_id)
    .then((response) => response.json())
    .then((data) => {
      const phone = data;
      const mensagem_atraso = `Olá ${usuario_nome}, o empréstimo de ${item_qntd}x ${item_nome} do dia ${data_emprestimo} está com ${dias_atraso} dia/dias de atraso!`;
      const url = `https://wa.me/55${phone}?text=${encodeURIComponent(
        mensagem_atraso
      )}`;
      window.open(url, "_blank");
    });
}

function getDelayedBorrows() {
  fetch("/get_emprestimos_atrasados")
    .then((response) => response.json())
    .then((data) => {
      let html = "";
      data.forEach((item) => {
        html += `<tr>
      <td>${item.usuario_nome}</td>
      <td>${item.item_nome}</td>s
      <td>${item.item_qntd}</td>
      <td>${item.data_emprestimo}</td>
      <td>${item.dias_atraso}</td>
      <td><button id="cobrar_bt" onclick="Cobrar('${item.emprestimo_id}', '${item.usuario_nome}', '${item.item_nome}', '${item.item_qntd}', '${item.data_emprestimo}', '${item.dias_atraso}')" style="font-size:24px">Cobrar <i class="fa fa-whatsapp"></i></button></td>
      </tr>`;
      });
      if (html == "") {
        document.getElementById(
          "EmprestimosAtrasados"
        ).innerHTML = `<tr><td colspan="6">Nenhum empréstimo atrasado</td></tr>`;
      } else {
        document.getElementById("EmprestimosAtrasados").innerHTML = html;
      }
    })
    .catch((error) =>
      console.error("Erro ao carregar emprestimos ativos:", error)
    );
}
function getHistoricBorrows() {
  fetch("/get_historico_emprestimos")
    .then((response) => response.json())
    .then((data) => {
      let html = "";
      data.forEach((item) => {
        html += `<tr>
      <td>${item.usuario_nome}</td>
      <td>${item.item_nome}</td>
      <td>${item.item_qntd}</td>
      <td>${item.data_emprestimo}</td>
      <td>${item.data_devolucao}</td>
      </tr>`;
      });
      if (html == "") {
        document.getElementById(
          "HistoricoEmprestimos"
        ).innerHTML = `<tr><td colspan="6">Nenhum empréstimo em historico</td></tr>`;
      } else {
        document.getElementById("HistoricoEmprestimos").innerHTML = html;
      }
    })
    .catch((error) =>
      console.error("Erro ao carregar emprestimos ativos:", error)
    );
}

function showAtivos() {
  document.getElementById("ativos").style.display = "block";
  getActiveBorrows();
  document.getElementById("atrasados").style.display = "none";
  document.getElementById("historico").style.display = "none";
}
function showAtrasados() {
  document.getElementById("atrasados").style.display = "block";
  getDelayedBorrows();
  document.getElementById("ativos").style.display = "none";
  document.getElementById("historico").style.display = "none";
}
function showHistorico() {
  document.getElementById("historico").style.display = "block";
  getHistoricBorrows();
  document.getElementById("atrasados").style.display = "none";
  document.getElementById("ativos").style.display = "none";
}

function returnItem(emprestimo_id) {
  const r = showConfirmDialog("Realmente desejar fazer a devolução do item?");
  r.then((res) => {
    if (res) {
      fetch("/return_item", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          emprestimo_id: emprestimo_id,
        }),
      })
        .then((response) => response.json())
        .then((data) => {
          if (data.status === "success") {
            showCustomAlert("Devolução feita com sucesso!", "success");
            getActiveBorrows();
          } else {
            showCustomAlert(data.message, "error");
          }
        });
    }
  });
}
let itens = [];
function borrowItemList() {
  const item_id = document.getElementById("itemSelect").value;
  const quantity = document.getElementById("itemQuantityInput").value;
  const content = document.getElementById("lista_de_itens");
  if (quantity < 1) {
    return;
  }
  for (let item of itens) {
    if (item[0] === item_id) {
      showCustomAlert("Item já adicionado à lista!", "error");
      return;
    }
  }
  fetch(
    `/check_item_emprestado?item_id=${item_id}&user_id=${
      document.getElementById("userSelect").value
    }`
  )
    .then((response) => response.json())
    .then((data) => {
      if (data.emprestado) {
        showCustomAlert("Item já emprestado!", "error");
      } else {
        itens.push([item_id, quantity]);
        content.style.display = "flex";
        fetch(`/get_item?item_id=${item_id}`)
          .then((response) => response.json())
          .then((data) => {
            content.innerHTML += `
  <li class="borrow-item">
  <span class="item-quantity">${quantity} x ${data.nome}</span>
  <button class="btn-delete" onClick="deleteItemInList(${item_id})" id="deleteItemList"> 🗑️</button>
  </li>`;
          })
          .catch((error) => {
            console.error("Erro ao adicionar item:", error);
          });
      }
    });
}
function deleteItemInList(item_id) {
  const itemIdNumber = Number(item_id);
  const itemIndex = itens.findIndex((item) => Number(item[0]) === itemIdNumber);

  itens.splice(itemIndex, 1);

  const itemList = document.getElementById("lista_de_itens");
  itemList.innerHTML = "";

  itens.forEach((item) => {
    const item_id = item[0];
    const quantity = item[1];

    fetch(`/get_item?item_id=${item_id}`)
      .then((response) => response.json())
      .then((data) => {
        itemList.innerHTML += `
        <li class="borrow-item">
        <span class="item-quantity">${quantity} x ${data.nome}</span>
        <button class="btn-delete" onClick="deleteItemInList(${item_id})" id="deleteItemList"> 🗑️</button>
        </li>`;
      })
      .catch((error) => {
        console.error("Erro ao buscar o item:", error);
      });
  });
}
function limparLista() {
  itens = [];
  document.getElementById("lista_de_itens").innerHTML = "";
}
function borrowItem() {
  if (!itens || itens.length === 0) {
    showCustomAlert("Não há itens na lista!", "error");
    return;
  }
  const userId = document.getElementById("userSelect").value;
  const DevolucaoPrevista = document.getElementById(
    "DevolucaoPrevistaInput"
  ).value;

  if (!DevolucaoPrevista) {
    showCustomAlert(
      "Por favor, coloque a data prevista para devolução.",
      "warning"
    );
    return;
  }

  fetch("/borrow_item", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      user_id: userId,
      items_id: itens,
      DevolucaoPrevista: DevolucaoPrevista,
    }),
  })
    .then((response) => response.json())
    .then((data) => {
      if (data.status === "success") {
        showCustomAlert("Item emprestado com sucesso!", "success");
        closePopup("borrowItemPopup");
        limparLista();
        getActiveBorrows();
      } else {
        showCustomAlert(data.message, "error");
      }
    })
    .catch((error) => {
      console.error("Erro ao emprestar item:", error);
    });
}

function showBorrowItemPopup() {
  fetch("/get_items")
    .then((response) => response.json())
    .then((items) => {
      const itemSelect = document.getElementById("itemSelect");
      itemSelect.innerHTML = items
        .map(
          (item) =>
            `<option value="${item[0]}">${item[1]} (ID: ${item[0]})</option>`
        )
        .join("");

      document.getElementById("borrowItemPopup").style.display = "flex";
      document.getElementById("DevolucaoPrevistaInput").value = "";
      document.getElementById("searchItemInput").value = "";
      document.getElementById("searchUserInput").value = "";
      GetEstoque();
      GetUsers();
    });
}
function searchItemsInPopup() {
  const search = document.getElementById("searchItemInput").value.toLowerCase();
  const itemSelect = document.getElementById("itemSelect");

  fetch(`/get_items?search=${search}`)
    .then((response) => response.json())
    .then((items) => {
      const options = items
        .map(
          (item) =>
            `<option value="${item[0]}">${item[1]} (ID: ${item[0]})</option>`
        )
        .join("");
      itemSelect.innerHTML = options;
      if (items.length === 1) {
        itemSelect.value = items[0][0];
        GetEstoque();
      }
    });
}
document.getElementById("itemSelect").addEventListener("change", function () {
  GetEstoque();
});
document
  .getElementById("searchItemInput")
  .addEventListener("input", function () {
    searchItemsInPopup();
  });
document
  .getElementById("searchUserInput")
  .addEventListener("input", function () {
    const searchTerm = this.value.toLowerCase();
    const content = document.getElementById("userSelect");

    fetch(`/get_users`)
      .then((response) => response.json())
      .then((users) => {
        let html = "";

        const filteredUsers = users.filter((user) =>
          user[2].toLowerCase().includes(searchTerm)
        );

        filteredUsers.forEach((user) => {
          html += `<option value="${user[0]}">${user[2]}</option>`;
        });

        content.innerHTML = html;
      })
      .catch((error) => {
        console.error("Erro ao carregar usuários:", error);
      });
  });

function GetEstoque() {
  const content = document.getElementById("itemQuantityInput");
  const itemId = document.getElementById("itemSelect").value;

  let html = "";
  if (itemId) {
    fetch(`/get_estoque?item_id=${itemId}`)
      .then((response) => response.json())
      .then((data) => {
        for (let i = 1; i <= data; i++) {
          html += `<option>${i}</option>`;
        }
        content.innerHTML = html;
      })
      .catch((error) => {
        console.error("Erro ao carregar estoque:", error);
      });
  }
}
function GetUsers() {
  const content = document.getElementById("userSelect");

  let html = "";

  fetch(`/get_users`)
    .then((response) => response.json())
    .then((users) => {
      users.forEach((user) => {
        html += `<option value="${user[0]}">${user[2]}</option>`;
      });

      content.innerHTML = html;
    })
    .catch((error) => {
      console.error("Erro ao carregar usuários:", error);
    });
}
