module PlutoPublish

import Pluto

export publisher


# direct usage
function publisher(e::Pluto.PlutoEvent)

end

# configured usage
function publisher(destination::String = "https://plutopublish.com")

end


end # module
