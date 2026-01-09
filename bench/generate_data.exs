# Generate benchmark test data files
# Run with: mix run bench/generate_data.exs

defmodule BenchmarkDataGenerator do
  @moduledoc """
  Generates XML test data files for benchmarking.

  Creates files with realistic XML features:
  - Nested elements
  - Attributes (with various types)
  - Text content
  - Namespaces
  - Entities
  - Comments
  """

  @data_dir "bench/data"

  def run do
    IO.puts("Generating benchmark test data...")

    generate_small()
    generate_medium()
    generate_large()

    IO.puts("\nData generation complete!")
    print_file_sizes()
  end

  defp generate_small do
    # ~1KB - Simple structure for baseline
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <catalog xmlns:test="http://example.com/test">
      <book id="1" category="fiction">
        <title>The Great Gatsby</title>
        <author>F. Scott Fitzgerald</author>
        <year>1925</year>
        <price currency="USD">10.99</price>
        <description>A story of decadence &amp; excess.</description>
      </book>
      <book id="2" category="non-fiction">
        <title>A Brief History of Time</title>
        <author>Stephen Hawking</author>
        <year>1988</year>
        <price currency="GBP">12.50</price>
        <description>Exploring the universe &amp; beyond.</description>
      </book>
      <!-- More books could be added here -->
      <metadata>
        <generated>#{DateTime.utc_now() |> DateTime.to_iso8601()}</generated>
        <version>1.0</version>
      </metadata>
    </catalog>
    """

    write_file("small.xml", xml)
  end

  defp generate_medium do
    # ~100KB - Moderate complexity
    items = for i <- 1..500 do
      category = Enum.random(["electronics", "books", "clothing", "food", "toys"])
      generate_item(i, category)
    end

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <inventory xmlns:inv="http://example.com/inventory"
               xmlns:test="http://example.com/test"
               generated="#{DateTime.utc_now() |> DateTime.to_iso8601()}">
      #{Enum.join(items, "\n")}
      <summary>
        <total_items>500</total_items>
        <categories>5</categories>
        <last_updated>#{Date.utc_today()}</last_updated>
      </summary>
    </inventory>
    """

    write_file("medium.xml", xml)
  end

  defp generate_large do
    # ~1MB - Large file with deep nesting
    departments = for d <- 1..10 do
      employees = for e <- 1..100 do
        projects = for p <- 1..5 do
          generate_project(d, e, p)
        end
        generate_employee(d, e, projects)
      end
      generate_department(d, employees)
    end

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <organization xmlns:org="http://example.com/org"
                  xmlns:hr="http://example.com/hr"
                  xmlns:test="http://example.com/test"
                  id="acme-corp"
                  generated="#{DateTime.utc_now() |> DateTime.to_iso8601()}">
      #{Enum.join(departments, "\n")}
      <metadata>
        <total_departments>10</total_departments>
        <total_employees>1000</total_employees>
        <total_projects>5000</total_projects>
        <report_date>#{Date.utc_today()}</report_date>
      </metadata>
    </organization>
    """

    write_file("large.xml", xml)
  end

  defp generate_item(id, category) do
    name = "Product #{id} - #{String.capitalize(category)} Item"
    price = :rand.uniform(10000) / 100
    stock = :rand.uniform(1000)

    """
      <item id="#{id}" category="#{category}" active="true">
        <name>#{escape(name)}</name>
        <sku>SKU-#{String.pad_leading(to_string(id), 6, "0")}</sku>
        <price currency="USD">#{:erlang.float_to_binary(price, decimals: 2)}</price>
        <stock quantity="#{stock}">
          <warehouse>WH-#{rem(id, 5) + 1}</warehouse>
          <reorder_level>#{div(stock, 10)}</reorder_level>
        </stock>
        <description>This is item ##{id} in the #{category} category. Features include quality &amp; durability.</description>
        <tags>
          <tag>#{category}</tag>
          <tag>item-#{id}</tag>
          <tag>#{if rem(id, 2) == 0, do: "sale", else: "regular"}</tag>
        </tags>
      </item>
    """
  end

  defp generate_department(id, employees) do
    names = ["Engineering", "Sales", "Marketing", "Finance", "HR",
             "Operations", "Legal", "Research", "Support", "Admin"]
    name = Enum.at(names, id - 1, "Department #{id}")

    """
      <org:department id="dept-#{id}" code="D#{String.pad_leading(to_string(id), 3, "0")}">
        <org:name>#{name}</org:name>
        <org:budget currency="USD">#{:rand.uniform(10_000_000)}</org:budget>
        <org:location floor="#{rem(id, 10) + 1}" building="HQ">
          <org:address>123 Corporate Ave, Floor #{rem(id, 10) + 1}</org:address>
        </org:location>
        <hr:employees count="#{length(employees)}">
    #{Enum.join(employees, "\n")}
        </hr:employees>
      </org:department>
    """
  end

  defp generate_employee(dept_id, emp_id, projects) do
    global_id = (dept_id - 1) * 100 + emp_id
    first_names = ["John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Eve", "Frank"]
    last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]

    first = Enum.random(first_names)
    last = Enum.random(last_names)
    salary = 50_000 + :rand.uniform(100_000)

    """
          <hr:employee id="emp-#{global_id}" department="dept-#{dept_id}">
            <hr:name>
              <hr:first>#{first}</hr:first>
              <hr:last>#{last}</hr:last>
            </hr:name>
            <hr:email>#{String.downcase(first)}.#{String.downcase(last)}@example.com</hr:email>
            <hr:title>#{Enum.random(["Engineer", "Manager", "Analyst", "Director", "Associate"])}</hr:title>
            <hr:salary currency="USD">#{salary}</hr:salary>
            <hr:hire_date>#{random_date()}</hr:hire_date>
            <hr:projects count="#{length(projects)}">
    #{Enum.join(projects, "\n")}
            </hr:projects>
          </hr:employee>
    """
  end

  defp generate_project(dept_id, emp_id, proj_id) do
    global_id = "P#{dept_id}-#{emp_id}-#{proj_id}"
    statuses = ["active", "completed", "on-hold", "planning"]

    """
              <test:project id="#{global_id}" status="#{Enum.random(statuses)}">
                <test:name>Project #{global_id}</test:name>
                <test:hours>#{:rand.uniform(500)}</test:hours>
              </test:project>
    """
  end

  defp random_date do
    year = 2015 + :rand.uniform(9)
    month = :rand.uniform(12)
    day = :rand.uniform(28)
    "#{year}-#{String.pad_leading(to_string(month), 2, "0")}-#{String.pad_leading(to_string(day), 2, "0")}"
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp write_file(name, content) do
    path = Path.join(@data_dir, name)
    File.write!(path, content)
    IO.puts("  Created #{path}")
  end

  defp print_file_sizes do
    IO.puts("\nFile sizes:")
    for name <- ["small.xml", "medium.xml", "large.xml"] do
      path = Path.join(@data_dir, name)
      size = File.stat!(path).size
      IO.puts("  #{name}: #{format_size(size)}")
    end
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"
end

BenchmarkDataGenerator.run()
