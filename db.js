var mongoose = require('mongoose');
var Schema = mongoose.Schema;
 
var Image = new Schema({
    filename  : String,
    author    : String,
    desc      : String,
    src       : String,
    orig_src  : String,
    parent_id : String, // this image based on the parent_id; default null?
    log       : [String],
    updated_at: Date
});
 
mongoose.model('Image', Image);
mongoose.connect('mongodb://localhost/infragram');
