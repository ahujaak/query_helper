module PatternQueryHelper
  class Sql

    attr_accessor :model, :query_string, :query_params, :query_filter, :results

    def initialize(
      model:, # the model to run the query against
      query:, # the custom sql to be executed
      query_params: {}, # a list of bind variables to be embedded into the query
      column_mappings: {}, # A hash that translates aliases to sql expressions
      filters: {}, # a list of filters in the form of {"comparate_alias"=>{"operator_code"=>"value"}}.  i.e. {"age"=>{"lt"=>100}, "children_count"=>{"gt"=>0}}
      sorts: "", # a comma separated string with a list of sort values i.e "age:desc,name:asc:lowercase"
      page: nil, # define the page you want returned
      per_page: nil, # define how many results you want per page
      single_record: false, # whether or not you expect the record to return a single result, if toggled, only the first result will be returned
      associations: [], # a list of activerecord associations you'd like included in the payload
      as_json_options: {}, # a list of as_json options you'd like run before returning the payload
      run: true # whether or not you'd like to run the query on initilization
    )
      @model = model
      @query_params = query_params
      @page = page.to_i if page
      @per_page = per_page.to_i if per_page
      @single_record = single_record
      @as_json_options = as_json_options

      # Create the query string object
      @query_string = PatternQueryHelper::QueryString.new(
        sql: query,
        page: @page,
        per_page: @per_page
      )

      # Create our column maps.  Use default maps if custom mappings aren't passed in.
      @column_maps = PatternQueryHelper::ColumnMap.create_from_hash(column_mappings)
      default_maps = @query_string.alias_map.map{|m| PatternQueryHelper::ColumnMap.new(**m)}
      default_maps.each do |m|
        @column_maps << m if @column_maps.select{|x| x.alias_name == m.alias_name}.empty?
      end

      # Create the filter and sort objects
      @query_filter = PatternQueryHelper::QueryFilter.new(filter_values: filters, column_maps: @column_maps)
      @sorts = PatternQueryHelper::Sort.new(sort_string: sorts, column_maps: @column_maps)
      @associations = PatternQueryHelper::Associations.process_association_params(associations)

      # Update the sql string with the filters and sorts
      @query_string.update(
        where_filters: @query_filter.where_filter_strings,
        having_filters: @query_filter.having_filter_strings,
        sorts: @sorts.sort_strings,
      )

      # Merge the filter bind variables into the query_params
      @query_params.merge!(@query_filter.bind_variables)

      execute_query() if run
    end

    def execute_query
      # Execute Sql Query
      @results = @model.find_by_sql([@query_string.build(), @query_params]) # Execute Sql Query
      @results = @results.first if @single_record # Return a single result if requested

      determine_count()
      load_associations()
      clean_results()
    end

    def payload
      if @page && @per_page
        {
          pagination: pagination_results(),
          data: @results
        }
      else
        { data: @results }
      end
    end

    private

    def pagination_results
      total_pages = (@count/(@per_page.nonzero? || 1).to_f).ceil
      next_page = @page + 1 if @page.between?(1, total_pages - 1)
      previous_page = @page - 1 if @page.between?(2, total_pages)
      first_page = @page == 1
      last_page = @page == total_pages
      out_of_range = !@page.between?(1,total_pages)

      {
        count: @count,
        current_page: @page,
        next_page: next_page,
        previous_page: previous_page,
        total_pages: total_pages,
        per_page: @per_page,
        first_page: first_page,
        last_page: last_page,
        out_of_range: out_of_range
      }
    end

    def clean_results
      @results.map!{ |r| r.except("_query_full_count") } if @page && @per_page
    end

    def load_associations
      @results = PatternQueryHelper::Associations.load_associations(
        payload: @results,
        associations: @associations,
        as_json_options: @as_json_options
      )
    end

    def determine_count
      # Determine total result count (unpaginated)
      @count = @page && @per_page && results.length > 0 ? results.first["_query_full_count"] : results.length
    end
  end
end
