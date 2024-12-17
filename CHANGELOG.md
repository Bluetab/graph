# Changelog

## [1.4.0] 2024-12-17

### Changed

- [TD-6911] Bump to Elixir 1.17 and updated dependencies
  - The following public functions were renamed to comply with credo standards:
    - Graph.is_tree/1 -> Graph.tree?/1
    - Graph.is_arborescence/1 -> Graph.arborescence?/1
    - Graph.is_acyclic?/1 -> Graph.acyclic?/1
    - Graph.ClusteredLevelGraph.is_proper?/1 -> Graph.ClusteredLevelGraph.proper?/1
    - Graph.LevelGraph.is_proper?/1 -> Graph.LevelGraph.proper?/1

## [1.3.0] 2022-10-26

### Changed

- [TD-5284] Update dependencies

## [1.2.0] 2021-06-29

### Fixed

- [TD-3867] Ensure rank assignment is consistent with topological ordering

## [1.1.0] 2021-03-04

### Fixed

- Maximum rank was being calculated incorrectly during rank assignment

### Changed

- Updated dependencies

## [1.0.0] 2020-07-01

### Added

- Breadth-first traversal with limit on number of levels

## [0.1.1] 2020-01-31

### Changed

- Assign random barycenter for nodes with degree 0
