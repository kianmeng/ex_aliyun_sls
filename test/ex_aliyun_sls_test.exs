defmodule ExAliyunSlsTest do
  use ExUnit.Case, async: false

  require Logger

  @backend {ExAliyunSls.LoggerBackend, :sls}

  alias ExAliyunSls.LoggerBackend.Client
  alias ExAliyunSls.{Log, LogTag, LoggerBackend}

  import LoggerBackend, only: [metadata_matches?: 2]

  setup do
    LoggerBackend.empty_package()
  end

  test "build one log" do
    Agent.start_link(fn -> LoggerBackend.get_source() end, name: :source)
    Agent.start_link(fn -> [] end, name: :log_package)
    Agent.start_link(fn -> 0 end, name: :log_count)
    timestamp = add_timestamp()
    result = LoggerBackend.build_one_log(:info, "test", timestamp, [])

    log = %Log{
      Contents: [
        %Log.Content{Key: "level", Value: "info"},
        %Log.Content{Key: "msg", Value: "test"}
      ],
      Time: timestamp
    }

    assert result == log
  end

  test "put logs" do
    logitems = [
      Log.new(
        Time: add_timestamp(),
        Contents: [
          Log.Content.new(Key: "file", Value: "ex_aliyun_sls/lib/ex_aliyun_sls/client.ex"),
          Log.Content.new(Key: "cc", Value: "cc1")
        ]
      ),
      Log.new(Time: add_timestamp(), Contents: [Log.Content.new(Key: "aa1", Value: "bb1")]),
      Log.new(Time: add_timestamp(), Contents: [Log.Content.new(Key: "aa", Value: "bb2")])
    ]

    logtags = [
      LogTag.new(Key: "haha", Value: "hehe"),
      LogTag.new(Key: "hey", Value: "test")
    ]

    source = LoggerBackend.get_source()
    sls_config = Application.get_env(:ex_aliyun_sls, :backend)
    logstore = Keyword.get(sls_config, :logstore)
    project = Keyword.get(sls_config, :project)
    endpoint = Keyword.get(sls_config, :endpoint)

    profile = %{
      project: project,
      endpoint: endpoint,
      access_key_id: Keyword.get(sls_config, :access_key_id),
      access_key: Keyword.get(sls_config, :access_key),
      host: project <> "." <> endpoint
    }

    {:ok, response} =
      Client.post_log_store_logs(%{
        topic: "topic_test",
        logitems: logitems,
        logstore: logstore,
        logtags: logtags,
        source: source,
        profile: profile
      })

    assert response == "success"
  end

  test "metadata_matches?" do
    assert metadata_matches?([a: 1], a: 1) == true
    assert metadata_matches?([b: 1], a: 1) == false
    assert metadata_matches?([b: 1], nil) == true
    assert metadata_matches?([b: 1, a: 1], a: 1) == true
    assert metadata_matches?([c: 1, b: 1, a: 1], b: 1, a: 1) == true
    assert metadata_matches?([a: 1], b: 1, a: 1) == false
  end

  test "add log to package" do
    config(level: :debug)
    assert LoggerBackend.get_count() == 0
    Logger.info("test 1")
    Process.sleep(1_000)
    assert LoggerBackend.get_count() == 1
    Logger.debug("test 2")
    Logger.error("test 3")
    Process.sleep(1_000)
    assert LoggerBackend.get_count() == 3
    Process.sleep(1_500)
    assert LoggerBackend.get_count() == 0
  end

  test "can configure log level" do
    config(level: :info)

    Logger.debug("hello")
    Process.sleep(1_000)
    assert LoggerBackend.get_count() == 0
  end

  defp add_timestamp do
    Timex.now()
    |> Timex.to_unix()
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end
end
