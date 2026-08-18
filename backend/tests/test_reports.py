class TestReports:
    def _create_product(self, client, auth_headers, name="Test", price=5000, stock=100):
        res = client.post(
            "/products",
            json={"name": name, "price_sell": price, "stock": stock},
            headers=auth_headers,
        )
        return res.json()

    def _create_tx(self, client, auth_headers, product_id, qty=2):
        return client.post(
            "/transactions",
            json={
                "items": [{"product_id": product_id, "qty": qty, "unit_name": "pcs"}],
                "payment_method": "tunai",
                "cash_received": 100000,
            },
            headers=auth_headers,
        )

    def test_daily_report(self, client, auth_headers):
        product = self._create_product(client, auth_headers)
        self._create_tx(client, auth_headers, product["id"])
        self._create_tx(client, auth_headers, product["id"], qty=3)

        res = client.get("/reports/daily", headers=auth_headers)
        assert res.status_code == 200
        data = res.json()
        assert data["summary"]["total_transactions"] >= 2
        assert data["summary"]["omzet"] > 0

    def test_monthly_report(self, client, auth_headers):
        product = self._create_product(client, auth_headers)
        self._create_tx(client, auth_headers, product["id"])

        res = client.get("/reports/monthly", headers=auth_headers)
        assert res.status_code == 200
        data = res.json()
        assert data["summary"]["total_transactions"] >= 1

    def test_top_products(self, client, auth_headers):
        product = self._create_product(client, auth_headers, name="Best Seller")
        self._create_tx(client, auth_headers, product["id"], qty=10)

        res = client.get("/reports/top-products", headers=auth_headers)
        assert res.status_code == 200
        top = res.json()
        assert len(top) >= 1
        assert top[0]["product_name"] == "Best Seller"
        assert top[0]["qty_sold"] == 10

    def test_reports_summary(self, client, auth_headers):
        product = self._create_product(client, auth_headers)
        self._create_tx(client, auth_headers, product["id"])

        res = client.get("/reports/summary", headers=auth_headers)
        assert res.status_code == 200
        data = res.json()
        assert "today" in data
        assert "this_month" in data
        assert "low_stock_count" in data
