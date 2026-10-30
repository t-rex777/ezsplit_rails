require "rails_helper"

RSpec.describe AppError, type: :model do
  def raised(error)
    raise error
  rescue => e
    e
  end

  it "groups repeats of the same error from the same place" do
    first = raised(RuntimeError.new("user 1 missing"))
    second = first.dup.tap { |e| e.set_backtrace(first.backtrace) }

    AppError.record(first, severity: :error, handled: false, source: "test", context: { controller: "groups" })
    AppError.record(second, severity: :error, handled: false, source: "test", context: { controller: "groups" })

    expect(AppError.count).to eq(1)
    expect(AppError.last.occurrences).to eq(2)
  end

  it "keeps errors from different endpoints apart" do
    error = raised(RuntimeError.new("boom"))

    AppError.record(error, severity: :error, handled: false, source: "test", context: { controller: "groups" })
    AppError.record(error, severity: :error, handled: false, source: "test", context: { controller: "expenses" })

    expect(AppError.count).to eq(2)
  end

  it "stores only small plain values from the context" do
    AppError.record(raised(RuntimeError.new("boom")), severity: :warning, handled: true, source: "test",
                    context: { job: Object.new, id: 5, name: :sym })

    expect(AppError.last.context).to eq("job" => "Object", "id" => 5, "name" => "sym")
  end

  it "picks up errors sent to Rails.error" do
    expect { Rails.error.handle { raise ArgumentError, "bad" } }.to change(AppError, :count).by(1)
    expect(AppError.last).to have_attributes(error_class: "ArgumentError", handled: true)
  end
end
