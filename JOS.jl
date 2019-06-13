struct GenericClass                                                             #Esta struct emula uma classe
    name
    superClasses
    slots                                                                       #as nossas slots sao guardadas num dicionario/mapa
end

struct Instance                                                                 #Esta struct emula uma classe
    name
    superClasses
    slots::Dict{Any,Any}                                                        #as nossas slots sao guardadas num dicionario/mapa
end

function make_class(name,supers,slots)                                          #Esta funcao cria classes
    if !isempty(supers)
        for x in supers
            for y in x.slots
                push!(slots,y)                                                  #herda os campos das superclasses
            end
        end
    end
    GenericClass(name,supers,slots)
end

function make_instance(classname,slots...)                                      #Esta função inicializa mesmo os valores das slots
    dict = Dict()
    for x in classname.slots
        dict[x]=nothing
    end
    for x in slots
        if x.first in classname.slots
            dict[x.first]=x.second                                              #campos inicializados a null
        else
            error(string("Slot ",x.first," is missing"))
        end
    end
    Instance(classname,classname.superClasses,dict)
end

function get_slot(obj, slot)
    if !(slot in keys(getfield(obj,:slots)))
        error(string("Slot ",slot," is missing"))
    end
    sl = getfield(obj,:slots)[slot]
    if sl==nothing
        error(string("Slot ",slot," is unbound"))
    end
    sl
end

function Base.getproperty(obj::Instance, sym::Symbol)
       return get_slot(obj, sym)
end

function set_slot!(obj, slot, val)
    sl = nothing
    if !(slot in keys(getfield(obj,:slots)))
        error(string("Slot ",slot," is missing"))
    end
    getfield(obj,:slots)[slot]=val
    sl = getfield(obj,:slots)[slot]
    if sl==nothing
        error(string("Slot ",slot," is unbound"))
    end
    sl
end

function Base.setproperty!(value::Instance, name::Symbol, x)
    set_slot!(value,name,x)
end

macro defclass(classname,supers,args...)
    fields = []
    for x in args
        push!(fields,:($(x)))
    end
    esc(quote $(classname) = make_class($(QuoteNode(classname)), :($$(supers)), :($$(fields)))
    end)
end

struct GenericFunction
    name
    parameters
    methods::Dict{Any,Any}                                                      #guardar os metodos da genericfunction -  as keys são tuplos com o tipo dos argumentos o value é uma λ
end

macro defgeneric(expr)
    name = expr.args[1]
    parameters =  tuple(expr.args[2:end]...)
    quote $(esc(name)) =
        GenericFunction($(esc(QuoteNode(name))),$(esc(parameters)),Dict())
    end
end

function get_supers_recursively(class_list)
    if isempty(class_list)
        return []
    end
    super_supers = []
    for el in class_list
        append!(super_supers,el.superClasses)
    end
    return append!(class_list,append!(super_supers,get_supers_recursively(super_supers)))
end

(f::GenericFunction)(args...) = let applicable=[],key=();
        for x in args
            key = (key...,getfield(x,:name).name);
        end
        if haskey(f.methods, key)
            f.methods[key](args...)
        else
            println(f.methods)
            for x in f.methods
                i = 1
                while i <= length(args)

                    if in(x.first[i], get_supers_recursively(getfield(args[i],:name).superClasses))
                        i += 1
                    else
                        break
                    end
                end
                if i == length(args)
                    push!(applicable,x)
                end
            end
            if isempty(applicable)
                error("No applicable method")
            else
                applicable[1].second(args...)
            end
        end
    end

macro defmethod(expr)
    name = expr.args[1].args[1]
    parameters =  expr.args[1].args[2:end]
    body = expr.args[2].args[2]
    parameterNames = ()
    parameterType = ()
    for x in parameters
        parameterNames = (parameterNames..., x.args[1])
        parameterType = (parameterType..., x.args[2])
    end
    esc(quote $(name).methods[$(parameterType)]=($(parameterNames...),)->$(body)
    end)
end
