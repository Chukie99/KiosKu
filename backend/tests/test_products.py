class TestProducts:
    def test_create_product(self, client, auth_headers):
        res = client.post(
            "/products",
            json={
                "name": "Indomie Goreng",
                "price_sell": 3000,
                "stock": 50,
                "barcode": "8991234567890",
            },
            headers=auth_headers,
        )
        assert res.status_code == 201
        data = res.json()
        assert data["name"] == "Indomie Goreng"
        assert data["price_sell"] == 3000
        assert data["stock"] == 50
        assert data["sku"] is not None

    def test_create_product_no_auth(self, client):
        res = client.post(
            "/products",
            json={"name": "Test", "price_sell": 1000},
        )
        assert res.status_code == 401

    def test_list_products(self, client, auth_headers):
        client.post(
            "/products",
            json={"name": "Produk A", "price_sell": 1000},
            headers=auth_headers,
        )
        client.post(
            "/products",
            json={"name": "Produk B", "price_sell": 2000},
            headers=auth_headers,
        )
        res = client.get("/products", headers=auth_headers)
        assert res.status_code == 200
        assert res.json()["total"] >= 2

    def test_search_products(self, client, auth_headers):
        client.post(
            "/products",
            json={"name": "Indomie Goreng", "price_sell": 3000},
            headers=auth_headers,
        )
        client.post(
            "/products",
            json={"name": "Indomie Rebus", "price_sell": 3000},
            headers=auth_headers,
        )
        client.post(
            "/products",
            json={"name": "Teh Pucuk", "price_sell": 4000},
            headers=auth_headers,
        )
        res = client.get("/products/search?q=Indomie", headers=auth_headers)
        assert res.status_code == 200
        assert len(res.json()) == 2

    def test_get_product_by_barcode(self, client, auth_headers):
        client.post(
            "/products",
            json={"name": "Kopi ABC", "price_sell": 2500, "barcode": "1234567890"},
            headers=auth_headers,
        )
        res = client.get("/products/barcode/1234567890", headers=auth_headers)
        assert res.status_code == 200
        assert res.json()["name"] == "Kopi ABC"

    def test_update_product(self, client, auth_headers):
        res = client.post(
            "/products",
            json={"name": "Old Name", "price_sell": 1000},
            headers=auth_headers,
        )
        pid = res.json()["id"]

        res2 = client.put(
            f"/products/{pid}",
            json={
                "name": "New Name",
                "price_sell": 2000,
            },
            headers=auth_headers,
        )
        assert res2.status_code == 200
        assert res2.json()["name"] == "New Name"
        assert res2.json()["price_sell"] == 2000

    def test_soft_delete_product(self, client, auth_headers):
        res = client.post(
            "/products",
            json={"name": "To Delete", "price_sell": 1000},
            headers=auth_headers,
        )
        pid = res.json()["id"]

        res2 = client.delete(f"/products/{pid}", headers=auth_headers)
        assert res2.status_code == 200
        assert res2.json()["ok"] is True

        res3 = client.get("/products", headers=auth_headers)
        names = [p["name"] for p in res3.json()["items"]]
        assert "To Delete" not in names

    def test_categories(self, client, auth_headers):
        res = client.post(
            "/categories",
            json={"name": "Makanan"},
            headers=auth_headers,
        )
        assert res.status_code == 201
        assert res.json()["name"] == "Makanan"

        res2 = client.get("/categories", headers=auth_headers)
        assert res2.status_code == 200
        assert len(res2.json()) >= 1

    def test_duplicate_category_rejected(self, client, auth_headers):
        client.post("/categories", json={"name": "Makanan"}, headers=auth_headers)
        res = client.post("/categories", json={"name": "Makanan"}, headers=auth_headers)
        assert res.status_code == 409

    def test_price_must_be_positive(self, client, auth_headers):
        res = client.post(
            "/products",
            json={"name": "Bad Product", "price_sell": 0},
            headers=auth_headers,
        )
        assert res.status_code == 422

    def test_stock_adjust(self, client, auth_headers):
        res = client.post(
            "/products",
            json={"name": "Adjust Test", "price_sell": 1000, "stock": 10},
            headers=auth_headers,
        )
        pid = res.json()["id"]

        res2 = client.post(
            "/stock/adjust",
            json={"product_id": pid, "change_qty": 5, "reason": "restock"},
            headers=auth_headers,
        )
        assert res2.status_code == 200
        assert res2.json()["stock"] == 15

        res3 = client.post(
            "/stock/adjust",
            json={"product_id": pid, "change_qty": -3, "reason": "koreksi"},
            headers=auth_headers,
        )
        assert res3.json()["stock"] == 12

    def test_stock_alerts(self, client, auth_headers):
        client.post(
            "/products",
            json={"name": "Low Stock", "price_sell": 1000, "stock": 2, "stock_alert_threshold": 5},
            headers=auth_headers,
        )
        res = client.get("/stock/alerts", headers=auth_headers)
        assert res.status_code == 200
        alerts = [a for a in res.json() if a["name"] == "Low Stock"]
        assert len(alerts) == 1
        assert alerts[0]["status"] == "menipis"
