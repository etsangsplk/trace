require './tracer'

class Noop
  include TracerInterface
  def start_span(op_name)
  end

  def inject(span_context, format, carrier)
  end

  def extract(format, carrier)
  end
end
