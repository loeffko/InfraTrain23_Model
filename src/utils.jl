# GENeSYS-MOD v3.1 [Global Energy System Model]  ~ March 2022
#
# #############################################################
#
# Copyright 2020 Technische Universität Berlin and DIW Berlin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# #############################################################

"""
Returns a `DataFrame` with the values of the variables from the JuMP container `var`.
The column names of the `DataFrame` can be specified for the indexing columns in `dim_names`,
and the name of the data value column by a Symbol `value_col` e.g. :Value
"""
function convert_jump_container_to_df(var::JuMP.Containers.DenseAxisArray;
    dim_names::Vector{Symbol}=Vector{Symbol}(),
    value_col::Symbol=:Value)

    if isempty(var)
        return DataFrame()
    end

    if length(dim_names) == 0
        dim_names = [Symbol("dim$i") for i in 1:length(var.axes)]
    end

    if length(dim_names) != length(var.axes)
        throw(ArgumentError("Length of given name list does not fit the number of variable dimensions"))
    end

    tup_dim = (dim_names...,)

    # With a product over all axis sets of size M, form an Mx1 Array of all indices to the JuMP container `var`
    ind = reshape([collect(k[i] for i in 1:length(dim_names)) for k in Base.Iterators.product(var.axes...)],:,1)

    var_val  = value.(var)

    df = DataFrame([merge(NamedTuple{tup_dim}(ind[i]), NamedTuple{(value_col,)}(var_val[(ind[i]...,)...])) for i in 1:length(ind)])

    return df
end


function read_time_series(year,inputdir,data_file,data_base_region,timeseries_data_file)
    XLSX.readxlsx(joinpath(inputdir, timeseries_data_file * ".xlsx"))
end

function read_in_data(year,inputdir,data_file,data_base_region,timeseries_data_file)
    XLSX.readxlsx(joinpath(inputdir, data_file * ".xlsx"))
end

function create_daa(in_data::XLSX.XLSXFile, tab_name, base_region="DE", els...;
    inherit_base_world=false,copy_world=false) # els contains the Sets, col_names is the name of the columns in the df as symbols
    df = DataFrame(XLSX.gettable(in_data[tab_name];first_row=5))
    # Initialize all combinations to zero:
    A = JuMP.Containers.DenseAxisArray(
        zeros(length.(els)...), els...)
    # Fill in values from Excel
    for r in eachrow(df)
        try
            A[r[1:end-1]...] = r.Value 
        catch err
            @debug err
        end
    end
    # Fill other values using base region
    if inherit_base_world
        for x in Base.Iterators.product(els...)
            if A[x...] == 0.0
                if A[base_region, x[2:end]...] != 0.0
                    A[x...] = A[base_region, x[2:end]...]
                elseif A["World", x[2:end]...] != 0.0
                    A[x...] = A["World", x[2:end]...]
                end
            end
        end
    end
    if copy_world
        for x in Base.Iterators.product(els...)
            A[x...] = A["World", x[2:end]...]
        end
    end
    if tab_name == "Par_CapacityToActivityUnit"
        for x in Base.Iterators.product(els...)
            if A[base_region, x[2:end]...] != 0.0
                A[x...] = A[base_region, x[2:end]...]
            elseif A["World", x[2:end]...] != 0.0
                A[x...] = A["World", x[2:end]...]
            else
                A[x...] = 0.0
            end
        end
    end
    if tab_name == "Par_EmissionsPenalty"
        for x in Base.Iterators.product(els...)
            if A[base_region, x[2:end]...] != 0.0
                A[x...] = A[base_region, x[2:end]...]
            else
                A[x...] = 0.0
            end
        end
    end
    return A
end

function create_daa(in_data::DataFrame, tab_name, base_region="DE", els...) # els contains the Sets, col_names is the name of the columns in the df as symbols
    df = in_data
    # Initialize all combinations to zero:
    A = JuMP.Containers.DenseAxisArray(
        zeros(length.(els)...), els...)
    # Fill in values from Excel
    for r in eachrow(df)
        try
            A[r[1:end-1]...] = r.y 
        catch err
            @debug err
        end
    end
    return A
end

function create_daa_init(in_data, tab_name, base_region="DE",init_value=0, els...;inherit_base_world=false,copy_world=false) # els contains the Sets, col_names is the name of the columns in the df as symbols
    """Same as create_daa but you can set the default value to be different than 0
    """
    df = DataFrame(XLSX.gettable(in_data[tab_name];first_row=5))
    # Initialize all combinations to zero:
    A = JuMP.Containers.DenseAxisArray(
        ones(length.(els)...)*init_value, els...)
    # Fill in values from Excel
    for r in eachrow(df)
        try
            A[r[1:end-1]...] = r.Value 
        catch err
            @debug err
        end
    end
    # Fill other values using base region
    if inherit_base_world
        for x in Base.Iterators.product(els...)
            if A[x...] == init_value
                if A[base_region, x[2:end]...] != init_value
                    A[x...] = A[base_region, x[2:end]...]
                elseif A["World", x[2:end]...] != init_value
                    A[x...] = A["World", x[2:end]...]
                end
            end
        end
    end
    if copy_world
        for x in Base.Iterators.product(els...)
            A[x...] = A["World", x[2:end]...]
        end
    end
    if tab_name == "Par_CapacityToActivityUnit"
        for x in Base.Iterators.product(els...)
            if A[base_region, x[2:end]...] != init_value
                A[x...] = A[base_region, x[2:end]...]
            elseif A["World", x[2:end]...] != init_value
                A[x...] = A["World", x[2:end]...]
            else
                A[x...] = init_value
            end
        end
    end
    if tab_name == "Par_EmissionsPenalty"
        for x in Base.Iterators.product(els...)
            if A[base_region, x[2:end]...] != init_value
                A[x...] = A[base_region, x[2:end]...]
            else
                A[x...] = init_value
            end
        end
    end
    return A
end

function df_from_json(ccd, Sets)
    df = DataFrame()
    region = Sets.Region_full
    technology = Sets.Technology
    year = Sets.Year
    for r in Symbol.(region), t in Symbol.(technology), y in Symbol.(string.(year))
        try
            push!(df, (region=r, technology=t, year=y, value=data(ccd, r, t, y,y)))
        catch e
            println(y)
        end
    end
    return df
end

function df_from_dd(dd, Sets)
    df = DataFrame()
    region = Sets.Region_full
    technology = Sets.Technology
    year = Sets.Year
    for r in At.(region), t in At.(technology), y in At.(year)
        push!(df, (region=r.val, technology=t.val, year=y.val, value=dd[r, t, y]))
    end
    return df
end

function df_from_daa(daa, Sets)
    df = DataFrame()
    region = Sets.Region_full
    technology = Sets.Technology
    year = Sets.Year
    for r in region, t in technology, y in year
        push!(df, (region=r, technology=t, year=y, value=daa[r, t, y]))
    end
    return df
end

function specified_demand_profile(time_series_data,Sets,base_region="DE")

    # Read table from Excel to DataFrame
    # Tbl = XLSX.gettable(time_series_data["Par_SpecifiedDemandProfile"];first_row=1)
    Tbl = XLSX.gettable(time_series_data["Par_SpecifiedDemandProfile"];
        header=false,
        infer_eltypes=true,
        column_labels=[:Region, :Fuel, :Timeslice, :Year, :Value])
    # return Tbl
    df = DataFrame(Tbl)
    A = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full), length(Sets.Fuel), length(Sets.Timeslice), length(Sets.Year)),
        Sets.Region_full, Sets.Fuel, Sets.Timeslice, Sets.Year)
    for r in eachrow(df)
        try
            A[r[1:end-1]...] = r.Value 
        catch err
            @debug err
        end
    end

    # Instantiate data to zero
    # A = zeros(Ti())

    # for r in eachrow(df)
    #     println(r)
    # end

    return A
end

function year_split(time_series_data,Sets,base_region="DE")

    # Read table from Excel to DataFrame
    # Tbl = XLSX.gettable(time_series_data["Par_SpecifiedDemandProfile"];first_row=1)
    Tbl = XLSX.gettable(time_series_data["Par_YearSplit"];
        header=false,
        infer_eltypes=true,
        column_labels=[:Timeslice, :Year, :Value])
    # return Tbl
    df = DataFrame(Tbl)
    A = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Timeslice), length(Sets.Year)),
        Sets.Timeslice, Sets.Year)
    for r in eachrow(df)
        try
            A[r[1:end-1]...] = r.Value 
        catch err
            @debug err
        end
    end

    # Instantiate data to zero
    # A = zeros(Ti())

    # for r in eachrow(df)
    #     println(r)
    # end

    return A
end

function capacity_factor(time_series_data,Sets,base_region="DE")

    # Read table from Excel to DataFrame
    # Tbl = XLSX.gettable(time_series_data["Par_SpecifiedDemandProfile"];first_row=1)
    Tbl = XLSX.gettable(time_series_data["Par_CapacityFactor"];
        header=false,
        infer_eltypes=true,
        column_labels=[:Region, :Technology, :Timeslice, :Year, :Value])
    # return Tbl
    df = DataFrame(Tbl)
    A = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full), length(Sets.Technology), length(Sets.Timeslice), length(Sets.Year)),
        Sets.Region_full, Sets.Technology, Sets.Timeslice, Sets.Year)
    for r in eachrow(df)
        try
            A[r[1:end-1]...] = r.Value 
        catch err
            @debug err
        end
    end

    # Instantiate data to zero
    # A = zeros(Ti())

    # for r in eachrow(df)
    #     println(r)
    # end

    return A
end

function read_x_peakingDemand(time_series_data,Sets,base_region="DE")

    # Read table from Excel to DataFrame
    # Tbl = XLSX.gettable(time_series_data["Par_SpecifiedDemandProfile"];first_row=1)
    Tbl = XLSX.gettable(time_series_data["x_peaking_demand"];
        header=false,
        infer_eltypes=true,
        column_labels=[:Region, :Sector, :Value])
    # return Tbl
    df = DataFrame(Tbl)
    A = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Region_full), length(Sets.Sector)),
        Sets.Region_full, Sets.Sector)
    for r in eachrow(df)
        try
            A[r[1:end-1]...] = r.Value 
        catch err
            @debug err
        end
    end

    # Instantiate data to zero
    # A = zeros(Ti())

    # for r in eachrow(df)
    #     println(r)
    # end

    return A
end

#= function read_MinActiveProductionPerTimeslice(time_series_data,Sets,base_region="DE")

    # Read table from Excel to DataFrame
    # Tbl = XLSX.gettable(time_series_data["Par_SpecifiedDemandProfile"];first_row=1)
    Tbl = XLSX.gettable(time_series_data["MinActiveRunperTimeslice"];
        header=false,
        infer_eltypes=true,
        column_labels=[:Timeslice, :Fuel, :Technology, :Year, :Value])
    # return Tbl
    df = DataFrame(Tbl...)
    A = JuMP.Containers.DenseAxisArray(
        zeros(length(Sets.Timeslice), length(Sets.Fuel),length(Sets.Technology),length(Sets.Year)),
        Sets.Timeslice, Sets.Fuel, Sets.Technology, Sets.Year)
    for r in eachrow(df)
        try
            A[r[1:end-1]...] = r.Value 
        catch err
            @debug err
        end
    end

    # Instantiate data to zero
    # A = zeros(Ti())

    # for r in eachrow(df)
    #     println(r)
    # end

    return A
end =#

function print_iis(model;filename="iis")
    list_of_conflicting_constraints = ConstraintRef[]
    for (F, S) in list_of_constraint_types(model)
        for con in all_constraints(model, F, S)
            if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
                push!(list_of_conflicting_constraints, con)
            end
        end
    end

    open("$(filename).txt", "w") do file
        for r in list_of_conflicting_constraints
            write(file, string(r)*"\n")
        end
    end
end