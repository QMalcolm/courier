defmodule CourierWeb.CoreComponentsTest do
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest
  import CourierWeb.CoreComponents

  describe "input/1 checkbox" do
    test "renders a checkbox with label" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <.input type="checkbox" id="c" name="c" value={false} label="Accept" errors={[]} />
            """
          end,
          %{}
        )

      assert html =~ ~s(type="checkbox")
      assert html =~ "Accept"
    end
  end

  describe "input/1 textarea" do
    test "renders a textarea with label" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <.input type="textarea" id="t" name="t" value="" label="Notes" errors={[]} />
            """
          end,
          %{}
        )

      assert html =~ "<textarea"
      assert html =~ "Notes"
    end
  end

  describe "list/1" do
    test "renders items with titles" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <.list>
              <:item title="Name">Alice</:item>
              <:item title="Email">alice@example.com</:item>
            </.list>
            """
          end,
          %{}
        )

      assert html =~ "Name"
      assert html =~ "Alice"
      assert html =~ "Email"
    end
  end

  describe "back/1" do
    test "renders a navigation back link" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <.back navigate="/home">Back to home</.back>
            """
          end,
          %{}
        )

      assert html =~ "/home"
      assert html =~ "Back to home"
    end
  end

  describe "translate_error/1" do
    test "translates error with count option using plural form" do
      result = translate_error({"must be at most %{count} characters", count: 10})
      assert is_binary(result)
    end
  end

  describe "translate_errors/2" do
    test "returns translated errors for a specific field" do
      errors = [name: {"can't be blank", []}, slug: {"is invalid", []}]
      result = translate_errors(errors, :name)
      assert result == ["can't be blank"]
    end
  end
end
