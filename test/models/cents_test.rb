require "test_helper"

class CentsTest < ActiveSupport::TestCase
  def test_converts_integer_cents_to_dollars
    assert_equal 123.34, Cents.to_dollars(123_34)
  end

  def test_returns_nil_for_nil_input
    # Cents.to_dollars(nil) should return nil — proves the "nil at the edges" Sandi rule
    assert_nil Cents.to_dollars(nil)
  end

  def test_handles_zero
    assert_equal 0.0, Cents.to_dollars(0)
  end
end
