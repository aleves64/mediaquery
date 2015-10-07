Promise = require 'bluebird'
querystring = require 'querystring'
urlparse = require 'url'

request = require '../request'
Media = require '../media'

ERR_NEED_API_KEY = new Error('Soundcloud requires an API key')
ERR_NOT_EMBEDDABLE = new Error('This track cannot be embedded')
ERR_NOT_FINISHED = new Error('This track failed or did not finish processing yet')

module.exports = class SoundcloudTrack extends Media
    type: 'soundcloud'

    shortCode: 'sc'

    apiKey: null

    resolve: ->
        if not @apiKey
            return Promise.reject(ERR_NEED_API_KEY)

        params = querystring.stringify(
            url: "https://soundcloud.com/#{@id}"
            client_id: @apiKey
        )

        url = "https://api.soundcloud.com/resolve.json?#{params}"

        return request.request(url).then((res) ->
            if res.statusCode == 302
                return res.headers['location']
            else
                throw new Error("Soundcloud returned #{res.statusCode}
                                #{res.statusMessage}")
        )

    fetch: (opts) ->
        @resolve().then((location) =>
            return request.getJSON(location).then((track) =>
                @seconds = Math.round(track.duration / 1000)
                @title = track.title
                @meta.thumbnail = track.artwork_url
                @meta.trackId = track.id

                if track.state != 'finished'
                    throw ERR_NOT_FINISHED

                if track.embeddable_by != 'all'
                    if opts.failNonEmbeddable
                        throw ERR_NOT_EMBEDDABLE
                    else
                        @meta.notEmbeddable = true

                if track.sharing == 'private'
                    @meta.privateURL = track.uri

                if opts.extract
                    return @extract()

                return this
            )
        )

    extract: ->
        url = "https://api.soundcloud.com/i1/tracks/#{@meta.trackId}/streams\
               ?client_id=#{@apiKey}"
        return request.getJSON(url).then((data) =>
            if data.http_mp3_128_url
                @meta.direct =
                    360: [{
                        contentType: 'audio/mp3'
                        link: data.http_mp3_128_url
                    }]
            return this
        ).catch((err) ->
            console.error("SoundcloudTrack::extract() failed: #{err.stack}")
            return this
        )

SoundcloudTrack.setAPIKey = (apiKey) ->
    SoundcloudTrack.prototype.apiKey = apiKey

###
# > SoundcloudTrack.parseURL(require('url').parse('https://soundcloud.com/zedd/bn-greyremix', true))
# {id: 'zedd/bn-greyremix', type: 'soundcloud'}
# > SoundcloudTrack.parseURL(require('url').parse('https://soundcloud.com/', true))
# null
# > SoundcloudTrack.parseURL(require('url').parse('https://developers.soundcloud.com/docs/api', true))
# null
###
SoundcloudTrack.parseURL = (url) ->
    data = urlparse.parse(url)
    if data.hostname != 'soundcloud.com'
        return null

    if not /\/[^\/]+\/[^\/]+/.test(data.pathname)
        return null

    return {
        type: SoundcloudTrack.prototype.type
        id: data.pathname.substring(1)
    }
