class TestAuth:
    def test_verify_pin_correct(self, client):
        res = client.post("/auth/verify-pin", json={"pin": "1234"})
        assert res.status_code == 200
        data = res.json()
        assert data["ok"] is True
        assert data["pin_set"] is True
        assert "token" in data
        assert len(data["token"]) > 10

    def test_verify_pin_wrong(self, client):
        res = client.post("/auth/verify-pin", json={"pin": "9999"})
        assert res.status_code == 200
        data = res.json()
        assert data["ok"] is False
        assert data["pin_set"] is True
        assert "token" not in data

    def test_protected_endpoint_no_token(self, client):
        res = client.get("/products")
        assert res.status_code == 401

    def test_protected_endpoint_invalid_token(self, client):
        res = client.get("/products", headers={"Authorization": "Bearer invalidtoken"})
        assert res.status_code == 401

    def test_protected_endpoint_valid_token(self, client, auth_headers):
        res = client.get("/products", headers=auth_headers)
        assert res.status_code == 200

    def test_logout_invalidates_token(self, client, auth_token):
        headers = {"Authorization": f"Bearer {auth_token}"}
        res = client.post("/auth/logout", headers=headers)
        assert res.status_code == 200
        assert res.json()["ok"] is True
        res2 = client.get("/products", headers=headers)
        assert res2.status_code == 401

    def test_health_no_auth(self, client):
        res = client.get("/health")
        assert res.status_code == 200
        assert res.json()["status"] == "ok"

    def test_settings_no_auth(self, client):
        res = client.get("/settings")
        assert res.status_code == 200

    def test_change_pin_requires_old_pin(self, client, auth_headers):
        res = client.post(
            "/auth/set-pin",
            json={"old_pin": "1234", "new_pin": "5678"},
            headers=auth_headers,
        )
        assert res.status_code == 200
        assert res.json()["ok"] is True

    def test_change_pin_wrong_old_pin(self, client, auth_headers):
        res = client.post(
            "/auth/set-pin",
            json={"old_pin": "0000", "new_pin": "5678"},
            headers=auth_headers,
        )
        assert res.status_code == 403

    def test_change_pin_too_short(self, client, auth_headers):
        res = client.post(
            "/auth/set-pin",
            json={"old_pin": "1234", "new_pin": "12"},
            headers=auth_headers,
        )
        assert res.status_code == 422
