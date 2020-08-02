defmodule Typelixir.ProcessorTest do
  use ExUnit.Case
  alias Typelixir.Processor

  describe "process_file" do
    @test_dir "test/tmp"

    @env %{
      :functions => %{
        "ModuleA.ModuleB" => %{
          {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
          {:test2, 0} => {:any, []},
          {:test3, 1} => {:any, [:integer]},
          {:test3, 2} => {:string, [:integer, :string]}
        },
        "ModuleC" => %{
          {:test, 2} => {:string, [:integer, :string]}
        },
        "Example" => %{}
      },
      :prefix => nil,
      :type => nil,
      :state => :ok,
      :error_data => %{},
      :data => %{},
      :vars => %{}
    }

    setup do
      File.mkdir(@test_dir)

      on_exit fn ->
        File.rm_rf @test_dir
      end
    end

    # NOTE -> we don't care about the type the module returns

    test "returns ok when there is no module or code defined on the file" do
      File.write("test/tmp/example.ex", "")
      assert Processor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []},
              {:test3, 1} => {:any, [:integer]},
              {:test3, 2} => {:string, [:integer, :string]}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{}
          },
          :prefix => nil,
          :type => :atom,
          :state => :ok,
          :error_data => %{},
          :data => %{},
          :vars => %{}
        }

      File.write("test/tmp/example.ex", "
        defmodule Example do
        end
      ")
      assert Processor.process_file("#{@test_dir}/example.ex", @env) 
        === %{
          :functions => %{
            "ModuleA.ModuleB" => %{
              {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
              {:test2, 0} => {:any, []},
              {:test3, 1} => {:any, [:integer]},
              {:test3, 2} => {:string, [:integer, :string]}
            },
            "ModuleC" => %{
              {:test, 2} => {:string, [:integer, :string]}
            },
            "Example" => %{}
          },
          :prefix => "Example",
          :type => {:list, {:tuple, [:atom, :any]}},
          :state => :ok,
          :error_data => %{},
          :data => %{},
          :vars => %{}
        }
    end

    # test "returns ok when there is no module or code defined on the file" do
    #   File.write("test/tmp/example.ex", "
    #     defmodule Example do
    #     end
    #   ")
    #   assert Processor.process_file("#{@test_dir}/example.ex", @env) 
    #     === %{
    #       :functions => %{
    #         "ModuleA.ModuleB" => %{
    #           {:test, 2} => {{:tuple, [{:list, :integer}, :string]}, [{:list, :integer}, :string]},
    #           {:test2, 0} => {:any, []},
    #           {:test3, 1} => {:any, [:integer]},
    #           {:test3, 2} => {:string, [:integer, :string]}
    #         },
    #         "ModuleC" => %{
    #           {:test, 2} => {:string, [:integer, :string]}
    #         }
    #       },
    #       :prefix => "Example",
    #       :type => {:list, {:tuple, [:atom, :any]}},
    #       :state => :ok,
    #       :error_data => %{},
    #       :data => %{},
    #       :vars => %{}
    #     }
    # end
  end
end