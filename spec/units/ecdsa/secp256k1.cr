require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Sushi::Core::ECDSA

describe Secp256k1 do
  secp256k1 = ECDSA::Secp256k1.new

  it "should return a point when calling #gp" do
    secp256k1.gp.x.should eq(BigInt.new("55066263022277343669578718895168534326250603453777594175500187360389116729240"))
    secp256k1.gp.y.should eq(BigInt.new("32670510020758816978083085130507043184471273380659243275938904335757337482424"))
    secp256k1.gp.infinity?.should eq(false)
  end

  it "should return an infinity point when calling #infinity" do
    secp256k1.infinity.x.should eq(BigInt.new(0))
    secp256k1.infinity.y.should eq(BigInt.new(0))
    secp256k1.infinity.infinity?.should eq(true)
  end

  it "should create a new key pair when calling #create_key_pair" do
    key_pair = secp256k1.create_key_pair
    key_pair[:secret_key].should be_a(BigInt)
    public_key = key_pair[:public_key]
    public_key.infinity?.should eq(false)
    public_key.x.should be_a(BigInt)
    public_key.y.should be_a(BigInt)
  end

  it "should create a public key from a secret key when calling #create_key_pair(secret_key)" do
    key_pair1 = secp256k1.create_key_pair
    public_key1 = key_pair1[:public_key]
    key_pair2 = secp256k1.create_key_pair(key_pair1[:secret_key])
    key_pair2[:secret_key].should eq(key_pair1[:secret_key])

    public_key = key_pair2[:public_key]
    public_key.infinity?.should eq(public_key1.infinity?)
    public_key.x.should eq(public_key1.x)
    public_key.y.should eq(public_key1.y)
  end

  it "should return [r,s] when successfully signed the message when calling #sign" do
    key_pair = secp256k1.create_key_pair
    result = secp256k1.sign(key_pair[:secret_key], "signing with secret key")
    result.size.should eq(2)
    result.first.should be_a(BigInt)
    result.last.should be_a(BigInt)
  end

  describe "#verify" do
    it "should return true if signed by a valid r,s" do
      key_pair = secp256k1.create_key_pair
      message = "signing with secret key"
      res = secp256k1.sign(key_pair[:secret_key], message)

      secp256k1.verify(key_pair[:public_key], message, res.first, res.last).should be_true
    end

    context "false" do
      it "should return false if signed by a different r,s" do
        key_pair = secp256k1.create_key_pair
        key_pair2 = secp256k1.create_key_pair
        message = "signing with secret key"
        res = secp256k1.sign(key_pair2[:secret_key], message)

        secp256k1.verify(key_pair[:public_key], message, res.first, res.last).should be_false
      end

      it "should return false if a different public key is provided" do
        key_pair = secp256k1.create_key_pair
        key_pair2 = secp256k1.create_key_pair
        message = "signing with secret key"
        res = secp256k1.sign(key_pair[:secret_key], message)

        secp256k1.verify(key_pair2[:public_key], message, res.first, res.last).should be_false
      end
    end
  end

  describe "core values" do
    it "should return the core values" do
      secp256k1._gx.should eq(BigInt.new("55066263022277343669578718895168534326250603453777594175500187360389116729240"))
      secp256k1._gy.should eq(BigInt.new("32670510020758816978083085130507043184471273380659243275938904335757337482424"))
      secp256k1._a.should eq(BigInt.new("0"))
      secp256k1._b.should eq(BigInt.new("7"))
      secp256k1._n.should eq(BigInt.new("115792089237316195423570985008687907852837564279074904382605163141518161494337"))
      secp256k1._p.should eq(BigInt.new("115792089237316195423570985008687907853269984665640564039457584007908834671663"))
    end
  end
    STDERR.puts "< ECDSA::Secp256k1"
end

# javascript:
# var hexPrivateKey = "47b9ffa2d50ae1049729dc53a1ad1235ad2fff57196740005cb9fd690c7076aa"
# var ecparams = all_crypto.ecurve.getCurveByName('secp256k1');
# var curvePt = ecparams.G.multiply(all_crypto.BigInteger.fromBuffer(hexstring2ab(hexPrivateKey)));
# var publicKey = ab2hexstring(curvePt.getEncoded(false))
# # 04dd2e7605289bfe2203ca34a934ba047674f19733570499ae79f13ec116d4b1364741474ebb51e0b359cd92f440c971d1684a90f77b512918593517f2cbac972f
#
# sushicoin:
# var hexPrivateKey = "47b9ffa2d50ae1049729dc53a1ad1235ad2fff57196740005cb9fd690c7076aa".to_big_i(16)
# key_pair = secp256k1.create_key_pair(hexPrivateKey)
# public_key = key_pair[:public_key].x.to_s(base: 16) + key_pair[:public_key].y.to_s(base: 16)
# # dd2e7605289bfe2203ca34a934ba047674f19733570499ae79f13ec116d4b1364741474ebb51e0b359cd92f440c971d1684a90f77b512918593517f2cbac972f
#
