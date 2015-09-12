urlparse = require 'url'
Promise = require 'bluebird'

{ getJSON } = require '../request'
Media = require '../media'

module.exports = class HitboxStream extends Media
    type: 'hitbox'

    shortCode: 'hb'

    fetch: (opts = {}) ->
        url = "https://www.hitbox.tv/api/media/live/#{@id}.json?showHidden=true"

        return getJSON(url).then((result) =>
            if result.error
                return Promise.reject(new Error("Hitbox error: #{result.error_msg}"))

            livestream = result.livestream[0]
            @title = "Hitbox.tv - #{livestream.media_user_name}"
            @meta.thumbnail = "http://edge.sf.hitbox.tv#{livestream.media_thumbnail}"
            return this
        )

###
# > HitboxStream.parseURL('http://hitbox.tv/foo')
# {id: 'foo', type: 'hitbox'}
# > HitboxStream.parseURL('http://www.hitbox.tv/foo')
# {id: 'foo', type: 'hitbox'}
###
HitboxStream.parseURL = (url) ->
    data = urlparse.parse(url)

    if data.hostname in ['hitbox.tv', 'www.hitbox.tv']
        return {
            type: HitboxStream.prototype.type
            id: data.pathname.substring(1)
        }
    else
        return null
