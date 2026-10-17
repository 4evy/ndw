# SHA-256 baselines for the corresponding files in /etc
{
  zprofile = [
    # Legacy baseline from nix-darwin 20b9f53, origin unspecified
    "db8422f92d8cff684e418f2dcffbb98c10fe544b5e8cd588b2009c7fa89559c5"
    # macOS
    "0235d3c1b6cf21e7043fbc98e239ee4bc648048aafaf6be1a94a576300584ef2"
    # macOS 26b1 and higher
    "f320016e2cf13573731fbee34f9fe97ba867dd2a31f24893d3120154e9306e92"
  ];
  zshrc = [
    # Legacy baseline from nix-darwin 20b9f53, origin unspecified
    "19a2d673ffd47b8bed71c5218ff6617dfc5e8533b240b9ba79142a45f8823c23"
    # macOS
    "fb5827cb4712b7e7932d438067ec4852c8955a9ff0f55e282473684623ebdfa1"
    # macOS 26b1 and higher
    "4d1ab5704f9d167a042fecac0d056c8a79a8ebd71e032d3489536c8db9ffe3e0"
    # official Nix installer
    "c5a00c072c920f46216454978c44df044b2ec6d03409dc492c7bdcd92c94a110"
    # official Nix installer
    "40b0d8751adae5b0100a4f863be5b75613a49f62706427e92604f7e04d2e2261"
    # official Nix installer (macOS 26b1 and higher)
    "bf76c5ed8e65e616f4329eccf662ee91be33b8bfd33713ce9946f2fe94fea7fa"
    # DeterminateSystems installer
    "2af1b563e389d11b76a651b446e858116d7a20370d9120a7e9f78991f3e5f336"
    # DeterminateSystems installer (macOS 26b1 and higher)
    "27274e44b88a1174787f9a3d437d3387edc4f9aaaf40356054130797f5dc7912"
  ];
  zshenv = [
    # DeterminateSystems installer
    "d07015be6875f134976fce84c6c7a77b512079c1c5f9594dfa65c70b7968b65f"
    # experimental official Nix installer 2.33.3
    "4e8f7cb9b699511f4ba5f9d5f8de1c9f5efb5c607de88faf5f58b8b9cb38edbf"
  ];
}
