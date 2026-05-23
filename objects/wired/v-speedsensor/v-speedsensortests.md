```jsonc
[
  // Basic functionality
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"mag\", \"value\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"xValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"yValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"xValue\" : 10, \"yValue\" : 10}}'",

  // Modes of comparison
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"mag\", \"mode\" : \"gte\", \"value\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"mag\", \"mode\" : \"gt\", \"value\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"mag\", \"mode\" : \"lt\", \"value\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"mag\", \"mode\" : \"lte\", \"value\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"mag\", \"mode\" : \"range\", \"value\" : [10, 20]}}'",

  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"xMode\" : \"gte\", \"xValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"xMode\" : \"gt\", \"xValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"xMode\" : \"lte\", \"xValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"xMode\" : \"lt\", \"xValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"xMode\" : \"range\", \"xValue\" : [10, 20]}}'",

  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"yMode\" : \"gte\", \"yValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"yMode\" : \"gt\", \"yValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"yMode\" : \"lte\", \"yValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"yMode\" : \"lt\", \"yValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"yMode\" : \"range\", \"yValue\" : [10, 20]}}'",

  // Errors
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"mag\", \"xMode\" : \"gte\", \"xValue\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"xMode\" : \"gte\", \"value\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : {\"valueToCompare\" : \"xy\", \"mode\" : \"gte\", \"value\" : 10}}'",
  "/spawnitem v-invisiblespeedsensor 1 '{\"detectVelocityComparison\" : null}'"
]
```