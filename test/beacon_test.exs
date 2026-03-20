defmodule BeaconTest do
  use ExUnit.Case

  test "parse_args returns port and dir" do
    opts = Beacon.parse_args(["--port", "8080", "--dir", "/some/path"])
    assert opts[:port] == 8080
    assert opts[:dir] == "/some/path"
  end

  test "parse_args returns empty list for no args" do
    opts = Beacon.parse_args([])
    assert opts == []
  end
end
