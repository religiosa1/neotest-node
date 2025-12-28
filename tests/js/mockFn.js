/** mock function to call */
module.exports.double = function (val) {
	if (!Number.isInteger(val)) throw new TypeError("Must be an int");
	console.log("making some noise here");
	return val * 2;
};
