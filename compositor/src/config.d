module composite.config;


struct NestedConfig {
    float animationSpeed;
    bool redirect;
    bool sortWorkspacesRecent;
}

__gshared NestedConfig config;
