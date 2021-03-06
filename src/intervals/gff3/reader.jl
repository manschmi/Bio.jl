
"""
    GFF3Reader(input::IO, save_directives::Bool=false)

Create a reader for data in GFF3 format.

# Arguments:
* `input`: data source
* `save_directives=false`: if true, store directive lines, which can be accessed
  with the `directives` function
"""
type GFF3Reader <: Bio.IO.AbstractReader
    state::Ragel.State
    version::VersionNumber
    sequence_regions::Vector{Interval{Void}}
    key::StringField
    save_directives::Bool
    entry_seen::Bool
    fasta_seen::Bool
    unescape_needed::Bool

    directive::StringField

    preceding_directives::Vector{StringField}
    preceding_directive_count::Int

    directives::Vector{StringField}
    directive_count::Int

    function GFF3Reader(input::BufferedInputStream, save_directives::Bool=false)
        return new(Ragel.State(gff3parser_start, input), VersionNumber(0), [],
                   StringField(), save_directives, false, false, false,
                   StringField(), StringField[], 0, StringField[], 0)
    end
end

# GFF3 can end before the end of the file if there is a FASTA directive
function Base.eof(reader::GFF3Reader)
    return reader.state.finished || eof(reader.state.stream)
end

function Bio.IO.stream(reader::GFF3Reader)
    return reader.state.stream
end

function Base.close(reader::GFF3Reader)
    # make trailing directives accessable
    reader.preceding_directives, reader.directives =
        reader.directives, reader.preceding_directives
    close(Bio.IO.stream(reader))
end

function Intervals.metadatatype(::GFF3Reader)
    return GFF3Metadata
end

function Base.eltype(::Type{GFF3Reader})
    return GFF3Interval
end

function GFF3Reader(input::IO; save_directives::Bool=false)
    return GFF3Reader(BufferedInputStream(input), save_directives)
end

function IntervalCollection(interval_stream::GFF3Reader)
    intervals = collect(GFF3Interval, interval_stream)
    return IntervalCollection{GFF3Metadata}(intervals, true)
end

"""
Return all directives that preceded the last GFF entry parsed as an array of
strings.

Directives at the end of the file can be accessed by calling `close(reader)`
and then `directives(reader)`.
"""
function directives(reader::GFF3Reader)
    return view(reader.preceding_directives, 1:reader.preceding_directive_count)
end

"""
Return true if the GFF3 stream is at its end and there is trailing FASTA data.
"""
function hasfasta(reader::GFF3Reader)
    if eof(reader)
        return reader.fasta_seen
    else
        error("GFF3 file must be read until the end before any FASTA sequences can be accessed")
    end
end

"""
Return a FASTAReader initialized to parse trailing FASTA data.

Throws an exception if there is no trailing FASTA, which can be checked using
`hasfasta`.
"""
function getfasta(reader::GFF3Reader)
    if !hasfasta(reader)
        error("GFF3 file has no FASTA data ")
    end
    return FASTAReader(reader.state.stream)
end
