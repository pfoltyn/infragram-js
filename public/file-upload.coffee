# This file is part of infragram-js.
#
# infragram-js is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# infragram-js is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with infragram-js.  If not, see <http://www.gnu.org/licenses/>.


socket = io.connect("http://localhost:8001")
upload = new FileReader()
file = null

handleOnChangeFile = (files, onLoadImage) ->
    if files && files[0]
        $("#progress-container").css("display", "inline-block")
        $("#file-container").css("display", "none")
        file = files[0]
        upload = new FileReader()
        upload.onload = (event) ->
            socket.emit("upload", {"name": file.name, "data": event.target.result})
        socket.emit("start", {"name": file.name, "size": file.size})

        reader = new FileReader()
        reader.onload = (event) ->
            img = new Image()
            img.onload = () -> onLoadImage(this)
            img.src = event.target.result
        reader.readAsDataURL(file)

getFilename = () ->
    return file.name

socket.on("more_data", (data) ->
    $("#progress-bar").css("width", data["percent"] + "%")
    $("#percent").html((Math.round(data["percent"] * 100) / 100) + "%")
    #The Next Blocks Starting Position
    place = data["place"] * 524288
    newFile = file.slice(place, place + Math.min(524288, file.size - place))
    upload.readAsBinaryString(newFile)
)

socket.on("done", (data) ->
    $("#progress-bar").css("width", "0%")
    $("#percent").html("0%")
    $("#progress-container").css("display", "none")
    $("#file-container").css("display", "inline-block")
)
