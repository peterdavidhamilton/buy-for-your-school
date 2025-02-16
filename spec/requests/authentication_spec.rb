require "rails_helper"

RSpec.describe "Authentication", type: :request do
  after(:each) do
    RedisSessions.redis.flushdb
    RedisSessionLookup.redis.flushdb
  end

  describe "Endpoints that don't require authentication" do
    it "the health_check endpoint is not authenticated" do
      get health_check_path
      expect(response).to have_http_status(:ok)
    end

    it "users can access the specification start page" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "users can access the planning guidance page" do
      get planning_path
      expect(response).to have_http_status(:ok)
    end

    it "users can access the new session endpoint" do
      post "/auth/dfe"
      expect(response).to have_http_status(:found)
    end

    it "DfE Sign-in can redirect users back to the service with the callback endpoint" do
      get auth_dfe_callback_path
      expect(response).to have_http_status(:found)
    end

    it "DfE Sign-in can sign users out" do
      get auth_dfe_signout_path
      expect(response).to have_http_status(:found)
    end
  end

  describe "Endpoints that do require authentication" do
    it "users cannot access the new journey path" do
      get new_journey_path
      expect(response).to redirect_to(root_path)
    end

    it "users cannot access an existing journey" do
      journey = create(:journey)
      get journey_path(journey)
      expect(response).to redirect_to(root_path)
    end

    it "users cannot edit an answer" do
      answer = create(:radio_answer)
      get edit_journey_step_path(answer.step.journey, answer.step)
      expect(response).to redirect_to(root_path)
    end

    it "users cannot see the journey map" do
      get new_journey_map_path
      expect(response).to redirect_to(root_path)
    end

    it "users cannot see the preview endpoints" do
      get preview_entry_path("an-entry-id")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "Sign out" do
    it "asks UserSession to repudiate the user's session data" do
      user_exists_in_dfe_sign_in
      expect_any_instance_of(UserSession).to receive(:repudiate!)

      get auth_dfe_signout_path

      expect(response).to redirect_to(root_path)
    end

    context "when there is no sign out token (they are already signed out from the applications point of view)" do
      it "redirects the user to the root path" do
        user_exists_in_dfe_sign_in
        allow_any_instance_of(UserSession)
          .to receive(:should_be_signed_out_of_dsi?).and_return(false)

        get auth_dfe_signout_path

        expect(response).to redirect_to(root_path)
      end
    end

    context "when there is a sign out token" do
      around do |example|
        ClimateControl.modify(
          DFE_SIGN_IN_ISSUER: "https://test-oidc.signin.education.gov.uk:443"
        ) do
          example.run
        end
      end

      it "redirects to DSI with the users token" do
        user_exists_in_dfe_sign_in
        allow_any_instance_of(UserSession)
          .to receive(:should_be_signed_out_of_dsi?).and_return(true)

        get auth_dfe_signout_path

        expect(response).to redirect_to("https://test-oidc.signin.education.gov.uk:443/session/end?id_token_hint=&post_logout_redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Fdfe%2Fsignout")
      end
    end
  end

  describe "Concurrent sign ins" do
    context "when a DSI user is already signed in" do
      after(:each) do
        RedisSessions.redis.flushdb
        RedisSessionLookup.redis.flushdb
      end

      before(:each) do
        # Simulate what session_store does with a new session
        RedisSessions.redis.set("redis:6379::2:1098345703928457320948572304",
          Marshal.dump({"_csrf_token" => "1", "dfe_sign_in_uid" => "123"}))

        # Simulate how we create a session lookup store
        RedisSessionLookup.redis.set("user_dsi_id:123", "2::1098345703928457320948572304")
      end

      it "destroys the previous users session so they have to authenticate again" do
        user_exists_in_dfe_sign_in(dsi_uid: "123")

        mock_redis = MockRedis.new
        allow(RedisSessions).to receive(:redis).and_return(mock_redis)
        expect(mock_redis).to receive(:del)
          .with("session:2::1098345703928457320948572304")
          .and_return(0)

        get auth_dfe_callback_path

        expect(response).to have_http_status(:found)
      end
    end
  end
end
