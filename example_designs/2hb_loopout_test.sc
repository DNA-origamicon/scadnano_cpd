{
  "version": "0.20.0",
  "groups": {
    "default_group": {
      "position": {"x": 0, "y": 0, "z": 0},
      "grid": "square"
    },
    "g1": {
      "position": {"x": 0, "y": 0, "z": 0},
      "grid": "honeycomb"
    }
  },
  "helices": [
    {"roll": 184.28571428571428, "grid_position": [0, -1], "group": "g1", "max_offset": 64},
    {"roll": 154.28571428571428, "grid_position": [0, 0], "group": "g1", "max_offset": 64}
  ],
  "strands": [
    {
      "color": "#32b86c",
      "sequence": "GGCGAGAAAGGTTGGAAAGCCGGC",
      "domains": [
        {"helix": 0, "forward": false, "start": 7, "end": 18, "label": "B"},
        {"loopout": 2},
        {"helix": 1, "forward": true, "start": 7, "end": 18, "label": "C"}
      ]
    },
    {
      "color": "#cc0000",
      "sequence": "TTGACGGTTAAGGGAA",
      "domains": [
        {"helix": 1, "forward": true, "start": 0, "end": 7, "label": "D"},
        {"loopout": 2},
        {"helix": 0, "forward": false, "start": 0, "end": 7, "label": "A"}
      ]
    },
    {
      "color": "#b8056c",
      "sequence": "TTCCCTTCCTTTCTCGCCACGTTCGCCGGCTTTCCCCGTCAA",
      "domains": [
        {"helix": 0, "forward": true, "start": 0, "end": 21},
        {"helix": 1, "forward": false, "start": 0, "end": 21}
      ]
    }
  ]
}