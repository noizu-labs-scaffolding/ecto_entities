#-------------------------------------------------------------------------------
# Author: Keith Brings <keith.brings@noizu.com>
# Copyright (C) 2023 Noizu Labs Inc. All rights reserved.
#-------------------------------------------------------------------------------

defmodule Noizu.Ecto.Entity.Enum do
  defmacro __using__(opts) do
    enum_name = opts[:name]
    values = opts[:values]
    default = opts[:default] || List.first(values)
    quote do
      @enum_name unquote(enum_name)
      @values unquote(values)
      @value_strings Enum.map(@values, &(Atom.to_string(&1)))
      use Ecto.Type

      def enum_name(), do: @enum_name
      def values(), do: @values

      def create(:postgres, types) do
        """
        DO $$ BEGIN
          CREATE TYPE #{enum_name()} as ENUM (#{Enum.map(types, &("'#{&1}'")) |> Enum.join(", ")});
        EXCEPTION
          WHEN duplicate_object THEN null;
        END $$;
        """
      end

      def update(:postgres, types) do
        insert = Enum.map(types, & "ALTER TYPE #{enum_name()} ADD VALUE '#{&1}';" )
        |> Enum.join("\n   ")
        """
        DO $$ BEGIN
          #{insert}
        END $$;
        """
      end



      def from_string(value) when is_binary(value) do
        case value do
          v when v in @value_strings -> {:ok, String.to_existing_atom(value)}
          _ -> {:error, "invalid value"}
        end
      end

      def from_atom(value) when is_atom(value) do
        if Enum.member?(@values, value) do
          {:ok, value}
        else
          {:error, :invalid_value}
        end
      end

      def type, do: Ecto.Enum

      def cast(value) when is_bitstring(value) do
        case from_string(value) do
          {:ok, result} -> {:ok, result}
          {:error, _} -> :error
          error ->
            :error
        end
      end

      def cast(value) when is_atom(value) do
        case from_atom(value) do
          {:ok, result} -> {:ok, result}
          {:error, error} ->
            :error
          error ->
            :error
        end
      end

      def load(value) do
        cast(value)
      end

      def dump(value) when is_bitstring(value) do
        #IO.puts "DUMP: #{inspect value}"
        case from_string(value) do
          {:ok, result} -> {:ok, Atom.to_string(result)}
          error ->
            error
        end
      end

      def dump(value) when is_atom(value) do
        case from_atom(value) do
          {:ok, result} -> {:ok, Atom.to_string(result)}
          error ->
            error
        end
      end
    end
  end
end
