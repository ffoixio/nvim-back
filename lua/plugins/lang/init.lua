return {
  { import = "plugins.lang.clangd" },
  { import = "plugins.lang.cmake" },
  { import = "plugins.lang.docker" },
  { import = "plugins.lang.git" },
  { import = "plugins.lang.go" },
  { import = "plugins.lang.json" },
  -- { import = "plugins.lang.julia" }, -- 关闭：系统未装 julia，要用时取消注释
  { import = "plugins.lang.make" }, -- Makefile + Justfile
  { import = "plugins.lang.nix" },
  { import = "plugins.lang.perl" },
  { import = "plugins.lang.python" },
  { import = "plugins.lang.rust" },
  { import = "plugins.lang.scala" },
  { import = "plugins.lang.sql" },
  { import = "plugins.lang.tcl" }, -- Tcl + xdc/nxdc/sdc/upf
  { import = "plugins.lang.toml" },
  { import = "plugins.lang.verilog" },
  { import = "plugins.lang.yaml" },
  { import = "plugins.lang.zig" }, -- 需要 zls，且系统要装 zig（pacman -S zig）
}
