require 'spec_helper'

describe Songkick::OAuth2::Provider::AccessToken do
  before do
    @alice = TestApp::User['Alice']
    @bob   = TestApp::User['Bob']

    create_authorization(
      :owner        => @alice,
      :client       => FactoryBot.create(:client),
      :scope        => 'profile',
      :access_token => 'sesame')

    @authorization = create_authorization(
      :owner        => @bob,
      :client       => FactoryBot.create(:client),
      :scope        => 'profile',
      :access_token => 'magic-key')

    Songkick::OAuth2::Provider.realm = 'Demo App'
  end

  let :token do
    Songkick::OAuth2::Provider::AccessToken.new(@bob, ['profile'], 'magic-key')
  end

  shared_examples_for "valid token" do
    it "is valid" do
      expect(token).to be_valid
    end
    it "does not add headers" do
      expect(token.response_headers).to eq({})
    end
    it "has an OK status code" do
      expect(token.response_status).to eq(200)
    end
    it "returns the owner who granted the authorization" do
      expect(token.owner).to eq(@bob)
    end
  end

  shared_examples_for "invalid token" do
    it "is not valid" do
      expect(token).to_not be_valid
    end
    it "does not return the owner" do
      expect(token.owner).to be_nil
    end
  end

  describe "with the right user, scope and token" do
    it_should_behave_like "valid token"
  end

  describe "with an implicit user" do
    let :token do
      Songkick::OAuth2::Provider::AccessToken.new(:implicit, ['profile'], 'magic-key')
    end
    it_should_behave_like "valid token"
  end

  describe "with no user" do
    let :token do
      Songkick::OAuth2::Provider::AccessToken.new(nil, ['profile'], 'magic-key')
    end
    it_should_behave_like "invalid token"

    it "returns an error response" do
      expect(token.response_headers['WWW-Authenticate']).to eq("OAuth realm='Demo App', error='invalid_token'")
      expect(token.response_status).to eq(401)
    end
  end

  describe "with less scope than was granted" do
    let :token do
      Songkick::OAuth2::Provider::AccessToken.new(@bob, [], 'magic-key')
    end
    it_should_behave_like "valid token"
  end

  describe "when the authorization has expired" do
    before { @authorization.update_attribute(:expires_at, 1.hour.ago) }
    it_should_behave_like "invalid token"

    it "returns an error response" do
      expect(token.response_headers['WWW-Authenticate']).to eq("OAuth realm='Demo App', error='expired_token'")
      expect(token.response_status).to eq(401)
    end
  end

  describe "with a non-existent token" do
    let :token do
      Songkick::OAuth2::Provider::AccessToken.new(@bob, ['profile'], 'is-the-password-books')
    end
    it_should_behave_like "invalid token"

    it "returns an error response" do
      expect(token.response_headers['WWW-Authenticate']).to eq("OAuth realm='Demo App', error='invalid_token'")
      expect(token.response_status).to eq(401)
    end
  end

  describe "with a token for the wrong user" do
    let :token do
      Songkick::OAuth2::Provider::AccessToken.new(@bob, ['profile'], 'sesame')
    end
    it_should_behave_like "invalid token"

    it "returns an error response" do
      expect(token.response_headers['WWW-Authenticate']).to eq("OAuth realm='Demo App', error='insufficient_scope'")
      expect(token.response_status).to eq(403)
    end
  end

  describe "with a token for an ungranted scope" do
    let :token do
      Songkick::OAuth2::Provider::AccessToken.new(@bob, ['offline_access'], 'magic-key')
    end
    it_should_behave_like "invalid token"

    it "returns an error response" do
      expect(token.response_headers['WWW-Authenticate']).to eq("OAuth realm='Demo App', error='insufficient_scope'")
      expect(token.response_status).to eq(403)
    end
  end

  describe "with no token string" do
    let :token do
      Songkick::OAuth2::Provider::AccessToken.new(@bob, ['profile'], nil)
    end
    it_should_behave_like "invalid token"

    it "returns an error response" do
      expect(token.response_headers['WWW-Authenticate']).to eq("OAuth realm='Demo App'")
      expect(token.response_status).to eq(401)
    end
  end
end

