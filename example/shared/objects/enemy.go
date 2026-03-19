components {
  id: "enemy"
  component: "/example/shared/objects/enemy.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"zoimbie1_hold\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/example/shared/examples.atlas\"\n"
  "}\n"
  ""
}
