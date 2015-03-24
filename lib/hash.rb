# rubocop:disable Documentation
class Hash
  def inspect
    to_json
  end
end
