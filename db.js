/*
 This file is part of infragram-js.

 infragram-js is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 2 of the License, or
 (at your option) any later version.

 infragram-js is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with infragram-js.  If not, see <http://www.gnu.org/licenses/>.
*/

var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var Image = new Schema({
    filename  : String,
    author    : String,
    title     : String,
    desc      : String,
    log       : String,
    updated_at: Date
});

mongoose.model('Image', Image);
mongoose.connect('mongodb://localhost/pfoltyn-infragram');
