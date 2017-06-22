/**
 * Make any changes you need to make to the database here
 */
export async function up () {
    this('project').update({}, {
        $set: { imageUrl: '' }
    });
}

/**
 * Make any changes that UNDO the up function side effects here (if possible)
 */
export async function down () {
    this('project').update({}, {
        $unset: { imageUrl: '' }
    });
}
