var mongoose = require('mongoose');
var marked = require('marked');
var Tag = require('./tag');
var Schema = mongoose.Schema;

var PostSchema = new Schema({
    title: String,
    body: {
        type: String,
        set: marked
    },
    markdown: { type: String, default: "" },
    description: { type: String, default: "To be done" },
    slug: {
        type: String,
        set: slugify
    },
    dateCreated: Date,
    isPublished: Boolean,
    tags: [{ type: Schema.Types.ObjectId, ref: 'Tag' }],
    project: { type: Schema.Types.ObjectId, ref: 'Project' }
});

/*
 * Creates a slug
 */
function slugify(text) {
    return text
        .toString().toLowerCase()
        .replace(/\s+/g, '-') // Replace spaces with -
        .replace(/[^\w\-]+/g, '') // Remove all non-word chars
        .replace(/\-\-+/g, '-') // Replace multiple - with single -
        .replace(/^-+/, '') // Trim - from start of text
        .replace(/-+$/, ''); // Trim - from end of text
}

/*
 * Transliteration
 */
function translit(text) {
    var letters = {
        'а': 'a',
        'б': 'b',
        'в': 'v',
        'г': 'g',
        'д': 'd',
        'е': 'e',
        'ё': 'e',
        'ж': 'zh',
        'з': 'z',
        'и': 'i',
        'й': 'j',
        'к': 'k',
        'л': 'l',
        'м': 'm',
        'н': 'n',
        'о': 'o',
        'п': 'p',
        'р': 'r',
        'с': 's',
        'т': 't',
        'у': 'u',
        'ф': 'f',
        'х': 'h',
        'ц': 'c',
        'ч': 'ch',
        'ш': 'sh',
        'щ': 'sh',
        'ъ': '\'',
        'ы': 'y',
        'ь': '\'',
        'э': 'e',
        'ю': 'yu',
        'я': 'ya'
    };

    var string = '';

    Array.prototype.forEach.call(text.toLowerCase(), function(char) {
        if (letters[char]) {
            string += letters[char];
        } else {
            string += char;
        }
    });

    return string;
}

PostSchema.pre('save', function(next) {
    if (!this.title || !this.markdown) {
        throw 'No valid post object is specified';
    }

    this.slug = this.title;
    this.body = this.markdown;
    this.dateCreated = Date.now();
    this.project = this.project || null;

    next();
});

module.exports = mongoose.model('Post', PostSchema);
