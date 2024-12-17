defmodule Graph.CrossingReductionTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.CrossingReduction

  @vertices [
              :grouped_sales,
              :sales,
              :web_statistics,
              :sites,
              :site_custom,
              :site_external,
              :site_segment,
              :site_segment_cvs,
              :site_web,
              :sites_dat,
              :ddddmmyy_tsv,
              :external_site_csv,
              :project,
              :visits,
              :pages_dat,
              :sqlcluster,
              :site_yyyymmdd_tsv,
              :pageviews,
              :v_pageviews,
              :pageviews_dat
            ]
            |> Enum.with_index(1)
            |> Map.new(fn {v, b} -> {v, %{b: b}} end)

  @edges [
    grouped_sales: :sqlcluster,
    sales: :sqlcluster,
    web_statistics: :grouped_sales,
    web_statistics: :sales,
    web_statistics: :sites_dat,
    web_statistics: :pages_dat,
    web_statistics: :pageviews_dat,
    sites: :site_custom,
    sites: :site_external,
    sites: :site_segment,
    sites: :site_web,
    site_custom: :project,
    site_external: :external_site_csv,
    site_segment: :site_segment_cvs,
    site_web: :site_yyyymmdd_tsv,
    sites_dat: :sites,
    visits: :ddddmmyy_tsv,
    pages_dat: :sqlcluster,
    pageviews: :visits,
    v_pageviews: :pageviews,
    pageviews_dat: :v_pageviews
  ]
  @tree [
    root: [
      blob: [
        stats: [
          output: [:web_statistics],
          source: [
            :grouped_sales,
            :pages_dat,
            :pageviews_dat,
            :sales,
            :sites_dat
          ]
        ],
        daily_stats: [
          daily_visits: [:ddddmmyy_tsv]
        ],
        site_stats: [
          src_site_cus: [:project],
          src_site_ext: [:external_site_csv],
          src_site_seg: [:site_segment_cvs],
          src_site_web: [:site_yyyymmdd_tsv]
        ]
      ],
      sqlon: [:sqlcluster],
      sqldb: [
        dwh: [:pageviews],
        dwh_views: [:v_pageviews],
        entity: [:sites],
        source_typed: [:site_custom, :site_external, :site_segment, :site_web],
        staging: [:visits]
      ]
    ]
  ]

  describe "Graph.CrossingReduction" do
    @tag vertices: @vertices
    @tag edges: @edges
    @tag tree: @tree
    test "sweep down", %{g: g, t: t} do
      crgs =
        g
        |> CrossingReduction.normalize(t)
        |> ClusteredLevelGraph.subgraph([10, 11])
        |> CrossingReduction.crossing_reduction_graphs(:down)

      assert %{blob: %{g: g1}, root: %{g: g0}, sqldb: %{g: g2}} = crgs

      assert edges(g0) |||
               [
                 {{:grouped_sales, :sqlcluster, 10}, {:grouped_sales, :sqlcluster, 11}},
                 {{:l, :blob, 10}, :blob},
                 {{:l, :root, 10}, {:l, :root, 11}},
                 {{:pages_dat, :sqlcluster, 10}, {:pages_dat, :sqlcluster, 11}},
                 {{:pageviews_dat, :v_pageviews, 10}, :sqldb},
                 {{:r, :blob, 10}, :blob},
                 {{:r, :root, 10}, {:r, :root, 11}},
                 {{:sales, :sqlcluster, 10}, {:sales, :sqlcluster, 11}},
                 {{:sites_dat, :sites, 10}, :sqldb}
               ]

      assert edges(g1) |||
               [
                 {{:l, :blob, 10}, {:l, :blob, 11}},
                 {{:r, :blob, 10}, {:r, :blob, 11}}
               ]

      assert edges(g2) |||
               [
                 {{:pageviews_dat, :v_pageviews, 10}, {:pageviews_dat, :v_pageviews, 11}},
                 {{:sites_dat, :sites, 10}, {:sites_dat, :sites, 11}}
               ]
    end

    @tag vertices: @vertices
    @tag edges: @edges
    @tag tree: @tree
    test "sweep up", %{g: g, t: t} do
      crgs =
        g
        |> CrossingReduction.normalize(t)
        |> ClusteredLevelGraph.subgraph([10, 11])
        |> CrossingReduction.crossing_reduction_graphs(:up)

      assert %{blob: %{g: g1}, stats: %{g: g2}, root: %{g: g0}} = crgs

      assert edges(g0) |||
               [
                 {{:grouped_sales, :sqlcluster, 11}, :blob},
                 {{:l, :blob, 11}, :blob},
                 {{:l, :root, 11}, {:l, :root, 10}},
                 {{:pages_dat, :sqlcluster, 11}, :blob},
                 {{:pageviews_dat, :v_pageviews, 11}, :blob},
                 {{:r, :blob, 11}, :blob},
                 {{:r, :root, 11}, {:r, :root, 10}},
                 {{:sales, :sqlcluster, 11}, :blob},
                 {{:sites_dat, :sites, 11}, :blob}
               ]

      assert edges(g1) |||
               [
                 {{:grouped_sales, :sqlcluster, 11}, :stats},
                 {{:l, :blob, 11}, {:l, :blob, 10}},
                 {{:pages_dat, :sqlcluster, 11}, :stats},
                 {{:pageviews_dat, :v_pageviews, 11}, :stats},
                 {{:r, :blob, 11}, {:r, :blob, 10}},
                 {{:sales, :sqlcluster, 11}, :stats},
                 {{:sites_dat, :sites, 11}, :stats}
               ]

      assert edges(g2) |||
               [
                 {{:grouped_sales, :sqlcluster, 11}, {:grouped_sales, :sqlcluster, 10}},
                 {{:pages_dat, :sqlcluster, 11}, {:pages_dat, :sqlcluster, 10}},
                 {{:pageviews_dat, :v_pageviews, 11}, {:pageviews_dat, :v_pageviews, 10}},
                 {{:sales, :sqlcluster, 11}, {:sales, :sqlcluster, 10}},
                 {{:sites_dat, :sites, 11}, {:sites_dat, :sites, 10}}
               ]
    end

    @tag vertices: @vertices
    @tag edges: @edges
    @tag tree: @tree
    test "constraints", %{g: g, t: t} do
      crossing_reduction =
        g
        |> CrossingReduction.normalize(t)
        |> ClusteredLevelGraph.subgraph([19, 20])
        |> CrossingReduction.crossing_reduction_graphs(:down)

      assert %{root: root, site_stats: site_stats} = crossing_reduction
      assert %{gc: gc1} = root
      assert %{gc: gc2} = site_stats

      assert [{v, w}] = edges(gc1)
      assert Enum.sort([v, w]) ||| [:blob, :sqldb]
      assert [{v1, w1}, {v2, w2}, {v3, w3}] = edges(gc2)

      assert [v1, v2, v3, w1, w2, w3] |> Enum.uniq() |> Enum.sort() |||
               [
                 :src_site_cus,
                 :src_site_ext,
                 :src_site_seg,
                 :src_site_web
               ]
    end

    @tag vertices: @vertices
    @tag edges: @edges
    @tag tree: @tree
    test "crossing reduction", %{g: g, t: t} do
      assert %ClusteredLevelGraph{crossings: 14} =
               CrossingReduction.clustered_crossing_reduction(g, t)
    end
  end
end
