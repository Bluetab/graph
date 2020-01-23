defmodule Graph.LayoutTest do
  use GraphCase
  use TreeCase

  alias Graph.ClusteredLevelGraph
  alias Graph.CrossingReduction
  alias Graph.Layout
  alias Graph.LevelGraph
  alias Graph.RankAssignment

  @vs2 [:sql1, :src1, :src2, :src3, :src4, :out1, :dwh11, :dwh21]
  @es2 [
    sql1: :src1,
    sql1: :src2,
    sql1: :src3,
    dwh11: :dwh21,
    dwh21: :src4,
    src1: :out1,
    src2: :out1,
    src3: :out1,
    src4: :out1
  ]
  @tr2 [
    root: [
      blob: [blob1: [src: [:src1, :src2, :src3, :src4], out: [:out1]]],
      dwh: [dwh1: [:dwh11], dwh2: [:dwh21]],
      sql: [:sql1]
    ]
  ]

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

  describe "Graph.Layout" do
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
      assert Enum.sort([v, w]) == [:blob, :sqldb]
      assert [{v1, w1}, {v2, w2}, {v3, w3}] = edges(gc2)

      assert [v1, v2, v3, w1, w2, w3] |> Enum.uniq() |> Enum.sort() == [
               :src_site_cus,
               :src_site_ext,
               :src_site_seg,
               :src_site_web
             ]
    end

    @tag vertices: @vertices
    @tag edges: @edges
    @tag tree: @tree
    test "layout clusters", %{g: g, t: t} do
      ids = [:web_statistics]
      assert %Layout{} = Layout.layout(g, t, ids)
    end

    @tag vertices: @vs2
    @tag edges: @es2
    @tag tree: @tr2
    test "splitting clusters", %{g: g, t: t} do
      # [:web_statistics]
      ids = [:sql1, :dwh11]
      assert %ClusteredLevelGraph{g: %{g: g} = lg} = clg = RankAssignment.assign_rank(g, t, ids)

      assert LevelGraph.is_proper?(lg)
      assert ClusteredLevelGraph.is_proper?(clg)

      assert %ClusteredLevelGraph{} = CrossingReduction.clustered_crossing_reduction(clg)
    end
  end

  def get_border_vertices(%LevelGraph{g: g}, id, side) do
    g
    |> Graph.vertices()
    |> Enum.filter(fn
      {^side, ^id, _} -> true
      _ -> false
    end)
  end
end
