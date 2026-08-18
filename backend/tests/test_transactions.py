class TestTransactions:
    def _create_product(self, client, auth_headers, name="Indomie", price=3000, stock=100):
        res = client.post(
            "/products",
            json={
                "name": name,
                "price_sell": price,
                "stock": stock,
            },
            headers=auth_headers,
        )
        assert res.status_code == 201
        return res.json()

    def test_create_transaction_decrements_stock(self, client, auth_headers):
        product = self._create_product(client, auth_headers, stock=50)
        product_id = product["id"]

        res = client.post(
            "/transactions",
            json={
                "items": [{"product_id": product_id, "qty": 5, "unit_name": "pcs"}],
                "payment_method": "tunai",
                "cash_received": 20000,
            },
            headers=auth_headers,
        )
        assert res.status_code == 201
        tx = res.json()
        assert tx["status"] == "selesai"
        assert tx["total_amount"] == 15000

        res2 = client.get(f"/products/{product_id}", headers=auth_headers)
        assert res2.status_code == 200
        assert res2.json()["stock"] == 45

    def test_void_restores_stock(self, client, auth_headers):
        product = self._create_product(client, auth_headers, stock=50)
        product_id = product["id"]

        res = client.post(
            "/transactions",
            json={
                "items": [{"product_id": product_id, "qty": 10, "unit_name": "pcs"}],
                "payment_method": "tunai",
                "cash_received": 50000,
            },
            headers=auth_headers,
        )
        tx_id = res.json()["id"]

        res2 = client.get(f"/products/{product_id}", headers=auth_headers)
        assert res2.json()["stock"] == 40

        res3 = client.post(
            f"/transactions/{tx_id}/void",
            json={"reason": "test void"},
            headers=auth_headers,
        )
        assert res3.status_code == 200
        assert res3.json()["status"] == "void"

        res4 = client.get(f"/products/{product_id}", headers=auth_headers)
        assert res4.json()["stock"] == 50

    def test_return_restores_stock(self, client, auth_headers):
        product = self._create_product(client, auth_headers, stock=50)
        product_id = product["id"]

        res = client.post(
            "/transactions",
            json={
                "items": [{"product_id": product_id, "qty": 10, "unit_name": "pcs"}],
                "payment_method": "tunai",
                "cash_received": 50000,
            },
            headers=auth_headers,
        )
        tx_id = res.json()["id"]

        res2 = client.post(
            f"/transactions/{tx_id}/return",
            json={"items": [{"product_id": product_id, "qty": 3, "unit_name": "pcs"}], "reason": "salah"},
            headers=auth_headers,
        )
        assert res2.status_code == 200

        res3 = client.get(f"/products/{product_id}", headers=auth_headers)
        assert res3.json()["stock"] == 43

    def test_utang_creates_debt(self, client, auth_headers):
        cust = client.post(
            "/customers",
            json={"name": "Pak Budi"},
            headers=auth_headers,
        )
        customer_id = cust.json()["id"]

        product = self._create_product(client, auth_headers, stock=50)

        res = client.post(
            "/transactions",
            json={
                "items": [{"product_id": product["id"], "qty": 2, "unit_name": "pcs"}],
                "payment_method": "utang",
                "customer_id": customer_id,
                "due_date": "2026-09-01",
            },
            headers=auth_headers,
        )
        assert res.status_code == 201
        assert res.json()["payment_method"] == "utang"

        debts = client.get("/debts", headers=auth_headers)
        assert len(debts.json()) >= 1
        pak_budi_debts = [d for d in debts.json() if d["customer_id"] == customer_id]
        assert len(pak_budi_debts) == 1
        assert pak_budi_debts[0]["total_debt"] == 6000

    def test_pay_debt(self, client, auth_headers):
        cust = client.post(
            "/customers",
            json={"name": "Pak Budi"},
            headers=auth_headers,
        )
        customer_id = cust.json()["id"]
        product = self._create_product(client, auth_headers)

        client.post(
            "/transactions",
            json={
                "items": [{"product_id": product["id"], "qty": 1, "unit_name": "pcs"}],
                "payment_method": "utang",
                "customer_id": customer_id,
                "due_date": "2026-09-01",
            },
            headers=auth_headers,
        )

        debts = client.get("/debts", headers=auth_headers)
        debt_id = debts.json()[0]["debts"][0]["id"]

        res = client.post(
            f"/debts/{debt_id}/pay",
            json={"amount_paid": 1500},
            headers=auth_headers,
        )
        assert res.status_code == 200
        assert res.json()["amount_paid"] == 1500
        assert res.json()["remaining"] == 1500
        assert res.json()["status"] == "sebagian"

        res2 = client.post(
            f"/debts/{debt_id}/pay",
            json={"amount_paid": 1500},
            headers=auth_headers,
        )
        assert res2.json()["status"] == "lunas"
        assert res2.json()["remaining"] == 0

    def test_empty_cart_rejected(self, client, auth_headers):
        res = client.post(
            "/transactions",
            json={
                "items": [],
                "payment_method": "tunai",
                "cash_received": 10000,
            },
            headers=auth_headers,
        )
        assert res.status_code == 422

    def test_list_transactions(self, client, auth_headers):
        product = self._create_product(client, auth_headers)
        client.post(
            "/transactions",
            json={
                "items": [{"product_id": product["id"], "qty": 1, "unit_name": "pcs"}],
                "payment_method": "tunai",
                "cash_received": 5000,
            },
            headers=auth_headers,
        )
        res = client.get("/transactions", headers=auth_headers)
        assert res.status_code == 200
        assert res.json()["total"] >= 1
