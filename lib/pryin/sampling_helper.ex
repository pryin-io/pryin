defmodule PryIn.SamplingHelper do
  @moduledoc false

  def should_sample(sample_rate \\ 1) do
    :rand.uniform() <= sample_rate
  end
end
