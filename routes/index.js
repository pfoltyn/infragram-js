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
var Image = mongoose.model('Image');
var upload = require('../upload');
var fs = require('fs');

exports.index = function (req, res) {
  var pageNumber = (req.query.page && (req.query.page > 0)) ? req.query.page : 1;
  var resultsPerPage = 8;
  var skipFrom = (pageNumber * resultsPerPage) - resultsPerPage;

  Image
    .find()
    .sort('-updated_at')
    .skip(skipFrom)
    .limit(resultsPerPage)
    .exec(function (err, images) {
      Image.count({}, function(error, count) {
        var pageCount = Math.ceil(count / resultsPerPage);
        if (pageCount == 0) {
          pageCount = 1;
        }
        res.render('index', {
          title: 'Infragram: online infrared image analysis',
          images: images,
          pageNumber: pageNumber,
          pageCount: pageCount
        });
      });
    });
};

exports.show = function(req, res){
  Image.findOne({ _id: req.params.id }, 'filename title desc author updated_at log', function (err, image) {
    if (err) return res.redirect('/');
    res.render('show', {
      image: image
    });
  })
};

exports.delete = function (req, res) {
  if (req.query.pwd == "easytohack") { // very temporary solution
    Image.findOne({_id: req.params.id}, 'filename', function (err, image) {
      if (err) return res.redirect('/');
      var obj = image.toObject();
      fs.unlink(upload.UPLOAD_PREFIX + obj.filename, function () {});
      fs.unlink(upload.UPLOAD_PREFIX + obj.filename + upload.THUMBNAIL_SUFIX, function () {});

      Image.remove({ _id: req.params.id }, function (err, image) {
        res.redirect('/');
      });
    });
  }
  else {
    res.redirect('/');
  }
};

exports.create = function (req, res) {
  var ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
  var filename = upload.getFilename({'name': req.body.filename}, 'no_date');
  fs.open(upload.UPLOAD_PREFIX + filename, 'r', function (err, fd) {
    if (err) {
      res.redirect('/');
    }
    else {
      fs.close(fd, function () {});
      new Image({
        filename: filename,
        title: req.body.title.substring(0, 25),
        author: req.body.author.substring(0, 25),
        desc: req.body.desc.substring(0, 50),
        log: req.body.log,
        updated_at: Date.now(),
        ip_addr: ip.substring(0, 40),
      }).save(function (err, todo, count) {
        res.redirect('/#new');
      });
    }
  });
};
