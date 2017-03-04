require "test_helper"
require "elements/template/compiler"

describe "Elements::Template::Compiler" do
  def compile(source, **options)
    Elements::Template::Compiler.compile(source, options)
  end

  it "should compile things" do
    source = <<-EOF.strip_heredoc
    require "some/lib"

    <template>
      <h1>Hello World</h1>

      <Views::MyView id="myid" data-attr="value">
        <ul>
          <li>one</li>
          <li>two</li>
        </ul>
      </Views::MyView>

      <footer>some text</footer>
    </template>
    EOF

    expected = <<-EOF.strip_heredoc
    require "elements/template"
    require "some/lib"

    module Views
      module Home
        class Template < Elements::Template::Base
          def default_options
            {}
          end

          def children
            [
              vnode("h1", {}, [
                vtext("Hello World")
              ]),
              Views::MyView.new({
                "id" => "myid",
                "data-attr" => "value"
              }, [
                vnode("ul", {}, [
                  vnode("li", {}, [
                    vtext("one")
                  ]),
                  vnode("li", {}, [
                    vtext("two")
                  ])
                ])
              ]),
              vnode("footer", {}, [
                vtext("some text")
              ])
            ]
          end
        end
      end
    end
    EOF

    compiled = compile(source.strip, filepath: "views/home/home.html")
    assert_equal expected.strip, compiled, "wrong compiled code"
  end
end
