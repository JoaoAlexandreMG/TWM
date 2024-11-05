window.onload = searchItems;
function searchItems() {
  const search = document.getElementById("itemSearch").value.toLowerCase(); 

  fetch(`/get_items?search=${search}`) 
    .then((response) => response.json())
    .then((items) => {
      const itemResults = document.getElementById("itemResults");

      itemResults.innerHTML = "";

      const filteredItems = items.filter((item) =>
        item[1].toLowerCase().includes(search)
      );

      filteredItems.sort((a, b) => a[0] - b[0]);

      if (filteredItems.length > 0) {
        filteredItems.forEach((item) => {
          const row = `
            <tr>

              <th >${item[0]}</th>
              <td>${item[1]}</td>
              <td style="text-align: center;">${item[2]}</td>
              <td style="text-align: center;">${item[3]}</td>
              <td style="text-align: center;">
                <button class="btn btn-primary btn-sm" onclick="openEditItemPopup(${item[0]}, '${item[1]}', ${item[3]}, '${item[2]}')">Editar</button>
              </td>
              <td><button onclick="deleteItem(${item[0]})" class="btn btn-danger btn-sm">Excluir</button></td>
            </tr>
          `;
          itemResults.insertAdjacentHTML("beforeend", row);
        });
      } else {
        itemResults.innerHTML = `<tr><td colspan="5">Nenhum item encontrado.</td></tr>`;
      }
    })
    .catch((error) => {
      console.error("Erro ao carregar itens:", error);
    });
}

function openEditItemPopup(itemId, itemName, itemQuantity, itemLocation) {
  document.getElementById("editItemId").value = itemId;
  document.getElementById("editItemName").value = itemName;
  document.getElementById("editItemQuantity").value = itemQuantity;
  document.getElementById("editItemLocation").value = itemLocation;
  document.getElementById("editItemPopup").style.display = "flex";
}
document.getElementById("itemSearch").addEventListener("input", searchItems);

document
  .getElementById("editItemForm")
  .addEventListener("submit", function (event) {
    event.preventDefault();

    const itemId = document.getElementById("editItemId").value;
    const itemName = document.getElementById("editItemName").value;
    const itemQuantity = document.getElementById("editItemQuantity").value;
    const itemLocation = document.getElementById("editItemLocation").value;

    fetch("/edit_item", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: `item_id=${itemId}&item_name=${itemName}&item_quantity=${itemQuantity}&item_location=${itemLocation}`,
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.status === "success") {
          closePopup("editItemPopup");
          showCustomAlert("Item editado com sucesso!", "success");
          searchItems();
        } else {
          showCustomAlert("Erro ao editar o item: " + data.message, "error");
        }
      })
      .catch((error) => {
        showCustomAlert("Erro ao editar o item: " + error, "error");
      });
  });
document
  .getElementById("addItemForm")
  .addEventListener("submit", function (event) {
    event.preventDefault();

    const itemName = document.getElementById("addItemName").value;
    const itemQuantity = document.getElementById("addItemQuantity").value;
    const itemLocation = document.getElementById("addItemLocation").value;

    fetch("/add_item", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        item_name: itemName,
        item_quantity: itemQuantity,
        item_location: itemLocation,
      }),
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.status === "success") {
          showCustomAlert("Item adicionado com sucesso!", "success");
          closePopup("addItemPopup");
          searchItems(); 
        } else {
          showCustomAlert(data.message, "success");
        }
      })
      .catch((error) => {
        console.error("Erro ao adicionar item:", error);
      });
  });
async function deleteItem(itemId) {
  const confirmDelete = await showConfirmDialog(
    "Tem certeza que deseja excluir este item?"
  );
  if (confirmDelete) {
    fetch("/delete_item", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        item_id: itemId,
      }),
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.status === "success") {
          showCustomAlert("Item excluído com sucesso!", "success");
          searchItems(); 
        } else {
          showCustomAlert(data.message, "success");
        }
      })
      .catch((error) => {
        console.error("Erro ao excluir item:", error);
      });
  }
}
