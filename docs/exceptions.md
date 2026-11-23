# Exceptions

| Rule | Reason | Revisit |
| --- | --- | --- |
| C7.4 | The validator, session lifecycle helpers and secret wrapper are Python because they drive the Archipelago Python toolchain and parse game YAML/APWorld data; TypeScript cannot replace them without a rewrite. | 2027-02-23 |
